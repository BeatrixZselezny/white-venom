#!/bin/bash
# branches/01-grub-injection.sh
# GRUB kernel commandline / kernelopts injection + backup + idempotence check
# Usage: sudo ./01-grub-injection.sh [--dry-run|--apply]
# Author: Beatrix Zelezny 🐱
set -euo pipefail

DRY_RUN=true
BACKUP_DIR="${BRANCH_BACKUP_DIR:-/var/backups/debootstrap_integrity}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
GRUBEDENV="$(command -v grub-editenv || true)"
GRUBENV_PATH="/boot/grub/grubenv"
GRUB_CFG="/etc/default/grub"

usage() {
  cat <<EOF
Usage: $0 [--dry-run|--apply]
  --dry-run : preview (default)
  --apply   : actually modify grub env with kernelopts
EOF
  exit 1
}

if [ $# -gt 0 ]; then
  case "$1" in
    --apply) DRY_RUN=false ;;
    --dry-run) DRY_RUN=true ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
fi

log() { echo "$(date +%F' '%T) $*"; }

log "[PRECHECK] Checking environment for GRUB injection..."
if [ -z "$GRUBEDENV" ]; then
  log "[WARN] grub-editenv not found in PATH. Fallback to /etc/default/grub editing."
fi
if [ ! -f "$GRUBENV_PATH" ]; then
  log "[WARN] $GRUBENV_PATH not found. grubenv may be elsewhere or absent."
fi
mkdir -p "$BACKUP_DIR"

# read current kernelopts (try grub-editenv first)
CURRENT_KERNELOPTS=""
if [ -n "$GRUBEDENV" ] && $GRUBEDENV list >/dev/null 2>&1; then
  # careful parsing: kernelopts=...
  CURRENT_KERNELOPTS=$($GRUBEDENV list | awk -F= '/kernelopts/ {sub(/^[^=]+=/,""); print substr($0,2)}' || true)
fi

# fallback to /etc/default/grub
if [ -z "$CURRENT_KERNELOPTS" ] && [ -f "$GRUB_CFG" ]; then
  CURRENT_KERNELOPTS=$(grep '^GRUB_CMDLINE_LINUX' "$GRUB_CFG" 2>/dev/null | cut -d'=' -f2- | sed 's/^"//;s/"$//' || true)
fi

log "[INFO] Current kernelopts: ${CURRENT_KERNELOPTS:-(none)}"

# desired options (canonical list)
read -r -d '' WANT_OPTS <<'EOF' || true
l1tf=full,force
smt=full,nosmt
spectre_v2=on
spec_store_bypass_disable=seccomp
slab_nomerge=yes
mce=0
pti=on
EOF

# Helper: check if a given WANT_OPT key exists in CURRENT_KERNELOPTS (match by key before '=')
has_key() {
  local key="$1"
  for tok in $CURRENT_KERNELOPTS; do
    if [ "${tok%%=*}" = "$key" ]; then
      return 0
    fi
  done
  return 1
}

# If all wanted keys already present (even if values differ?), we treat more strictly:
# We'll consider "already applied" only if for each WANT_OPT exact token exists in CURRENT_KERNELOPTS.
all_present=true
while read -r want; do
  [ -z "$want" ] && continue
  # exact token match
  token_found=false
  for tok in $CURRENT_KERNELOPTS; do
    if [ "$tok" = "$want" ]; then
      token_found=true
      break
    fi
  done
  if ! $token_found; then
    all_present=false
    break
  fi
done <<< "$WANT_OPTS"

if $all_present; then
  log "[IDEMPOTENT] All desired kernelopts already present. Nothing to do."
  exit 0
fi

# Build new kernelopts: keep existing tokens except those that WILL be overridden by WANT_OPTS
build_new_kernelopts() {
  declare -A seen
  new=""
  # record wanted keys for replacement
  declare -A wantkeys
  while read -r w; do
    [ -z "$w" ] && continue
    wantkeys["${w%%=*}"]=1
  done <<< "$WANT_OPTS"

  # keep existing tokens that are not in wantkeys
  for tok in $CURRENT_KERNELOPTS; do
    key="${tok%%=*}"
    if [ -n "${wantkeys[$key]:-}" ]; then
      # skip existing token to be replaced by WANT_OPTS
      continue
    fi
    new="$new $tok"
    seen["$key"]=1
  done

  # append WANT_OPTS (avoid duplicates)
  while read -r w; do
    [ -z "$w" ] && continue
    k="${w%%=*}"
    if [ -z "${seen[$k]:-}" ]; then
      new="$new $w"
      seen["$k"]=1
    fi
  done <<< "$WANT_OPTS"

  # trim
  echo "$new" | awk '{$1=$1;print}'
}

NEW_KERNELOPTS="$(build_new_kernelopts)"
log "[INFO] New kernelopts planned: $NEW_KERNELOPTS"

# If dry-run, just show planned change
if $DRY_RUN; then
  log "[DRY-RUN] Would backup grubenv and set kernelopts to:"
  echo "  $NEW_KERNELOPTS"
  exit 0
fi

# APPLY flow: idempotence safety - check again current value before writing
# reload current to ensure race-free
CURR_AFTER=$($GRUBEDENV list 2>/dev/null | awk -F= '/kernelopts/ {sub(/^[^=]+=/,""); print substr($0,2)}' || true)
if [ -z "$CURR_AFTER" ] && [ -f "$GRUB_CFG" ]; then
  CURR_AFTER=$(grep '^GRUB_CMDLINE_LINUX' "$GRUB_CFG" 2>/dev/null | cut -d'=' -f2- | sed 's/^"//;s/"$//' || true)
fi

# if someone else already applied identical NEW_KERNELOPTS, do nothing
if [ "$CURR_AFTER" = "$NEW_KERNELOPTS" ]; then
  log "[IDEMPOTENT] New kernelopts already set by another run. Nothing to do."
  exit 0
fi

# backup files
if [ -f "$GRUBENV_PATH" ]; then
  cp -a "$GRUBENV_PATH" "$BACKUP_DIR/grubenv.$TIMESTAMP.bak" || true
  log "[BACKUP] $GRUBENV_PATH -> $BACKUP_DIR/grubenv.$TIMESTAMP.bak"
fi
if [ -f "$GRUB_CFG" ]; then
  cp -a "$GRUB_CFG" "$BACKUP_DIR/grub_default.$TIMESTAMP.bak" || true
  log "[BACKUP] $GRUB_CFG -> $BACKUP_DIR/grub_default.$TIMESTAMP.bak"
fi

# write using grub-editenv if available
if [ -n "$GRUBEDENV" ]; then
  setval="kernelopts=$NEW_KERNELOPTS"
  log "[ACTION] grub-editenv set \"$setval\""
  grub-editenv set "$setval"
  log "[OK] grub-editenv updated"
else
  # fallback to edit /etc/default/grub safely:
  if [ -f "$GRUB_CFG" ]; then
    # create new GRUB_CMDLINE_LINUX line (idempotent replacement)
    sed -i.bak.$TIMESTAMP -E "s/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"$NEW_KERNELOPTS\"/" "$GRUB_CFG" || true
    # if no line existed, append
    if ! grep -q '^GRUB_CMDLINE_LINUX' "$GRUB_CFG"; then
      echo "GRUB_CMDLINE_LINUX=\"$NEW_KERNELOPTS\"" >> "$GRUB_CFG"
    fi
    log "[ACTION] Updated $GRUB_CFG GRUB_CMDLINE_LINUX (fallback path). Backup: ${GRUB_CFG}.bak.$TIMESTAMP"
    if command -v update-grub >/dev/null 2>&1; then
      update-grub || log "[WARN] update-grub failed"
    fi
  else
    log "[ERROR] Cannot set kernelopts: neither grub-editenv nor $GRUB_CFG present."
    exit 5
  fi
fi

log "[DONE] GRUB kernelopts updated. Backup at $BACKUP_DIR"
exit 0
