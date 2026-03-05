#!/usr/bin/env bash
# 05_dpkg_apt_hardening.sh
#
# White Venom – APT/DPKG hardening baseline (no-systemd enforcement)
#
# Goals:
# - Enforce "no systemd drift" via APT Pre-Install hook (dpkg preinstall filter)
# - Reduce attack surface: no recommends/suggests, HTTPS-only acquisition (fail closed)
# - Be audit-friendly: strict --dry-run (no filesystem writes, no apt operations)
# - Be rollback-safe: restore only WV-owned files, do NOT wipe /etc/apt/*
#
# NOTE:
# - Systemd PINNING is intentionally NOT used here (pinning can poison APT resolution).
# - If you previously used pinning, remove it from /etc/apt/preferences(.d) and keep this hook.
#
set -euo pipefail

SCRIPT_NAME="05_DPKG_APT_HARDENING"

APT_CONF_DIR="/etc/apt/apt.conf.d"
LOG_DIR="/var/log/whitevenom"
LOGFILE="$LOG_DIR/apt-preinstall.log"

WV_ETC_DIR="/etc/whitevenom"
BYPASS_FILE="$WV_ETC_DIR/apt_hook_bypass"   # emergency switch: if exists -> hook allows everything

BRANCH_BACKUP_DIR="${BACKUP_DIR:-/var/backups/debootstrap_integrity/05}"
SNAPSHOT_ROOT="$BRANCH_BACKUP_DIR/snapshots"

HOOK_DIR="/usr/local/libexec/whitevenom"
HOOK_SCRIPT="$HOOK_DIR/wv_apt_preinstall_filter.sh"

# WV-owned files (only these are backed up/restored by this module)
WV_FILES=(
  "$APT_CONF_DIR/99-preinstall-filter"
  "$APT_CONF_DIR/99-no-recommends-suggests"
  "$APT_CONF_DIR/99-apt-https-only"
  "$HOOK_SCRIPT"
)

# Minimal, purpose-specific blacklist (avoid "APT-megmérgezés" by overblocking)
# Add more only if you are willing to accept install failures due to transitive deps.
BLACKLIST=(
  systemd
  systemd-sysv
  systemd-timesyncd
  systemd-resolved
  libsystemd0
  libsystemd-journal0
  libsystemd-shared
)

log() {
  local level="$1"; shift
  printf "%s [%s/%s] %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$SCRIPT_NAME" "$level" "$*"
}

usage() {
  cat <<EOF
Használat: $0 [--dry-run | --apply | --restore]

  --dry-run   csak kiírja, mit tenne (nem ír fájlt, nem futtat apt-get-et)
  --apply     konfigurálás: APT policy + Pre-Install hook + opcionális toolchain sanity
  --restore   visszaállítás az utolsó snapshotból ($SNAPSHOT_ROOT/<timestamp>)

Vészkapcsoló (hook bypass):
  - Ha létezik: $BYPASS_FILE, akkor az APT hook mindent átenged (csak logol).

EOF
}

MODE="${1:-}"
DRY_RUN=false

case "$MODE" in
  --dry-run) DRY_RUN=true ;;
  --apply)   DRY_RUN=false ;;
  --restore) DRY_RUN=false ;;
  *) usage; exit 1 ;;
esac

if [[ "$(id -u)" -ne 0 ]]; then
  log "FATAL" "Rootként futtasd."
  exit 1
fi

run_cmd() {
  if $DRY_RUN; then
    log "DRY" "$*"
  else
    "$@"
  fi
}

latest_snapshot_dir() {
  if [[ ! -d "$SNAPSHOT_ROOT" ]]; then
    return 1
  fi
  ls -1 "$SNAPSHOT_ROOT" 2>/dev/null | sort | tail -n1
}

make_snapshot() {
  local ts snap manifest
  ts="$(date +%Y%m%d-%H%M%S)"
  snap="$SNAPSHOT_ROOT/$ts"
  manifest="$snap/manifest.tsv"

  if $DRY_RUN; then
    log "DRY" "Would create snapshot dir: $snap"
    for f in "${WV_FILES[@]}"; do
      if [[ -e "$f" ]]; then
        log "DRY" "Would backup existing: $f"
      else
        log "DRY" "Would record missing: $f"
      fi
    done
    return 0
  fi

  mkdir -p "$snap"
  chmod 700 "$snap" || true

  : > "$manifest"
  for f in "${WV_FILES[@]}"; do
    local b existed
    b="$(basename "$f")"
    existed=0
    if [[ -e "$f" ]]; then
      existed=1
      cp -a "$f" "$snap/$b.orig" 2>/dev/null || true
    fi
    printf "%s\t%s\t%s\n" "$f" "$existed" "$b.orig" >> "$manifest"
  done

  log "INFO" "Snapshot created: $snap"
}

restore_from_snapshot() {
  local snap_id snap manifest
  snap_id="$(latest_snapshot_dir || true)"
  if [[ -z "${snap_id:-}" ]]; then
    log "WARN" "Nincs snapshot a restore-hoz: $SNAPSHOT_ROOT"
    return 0
  fi

  snap="$SNAPSHOT_ROOT/$snap_id"
  manifest="$snap/manifest.tsv"

  if $DRY_RUN; then
    log "DRY" "Would restore from snapshot: $snap"
    log "DRY" "Would remove WV files and restore originals where existed."
    return 0
  fi

  if [[ ! -f "$manifest" ]]; then
    log "WARN" "Hiányzó manifest: $manifest (nem tudok biztos restore-t csinálni)"
    return 1
  fi

  while IFS=$'\t' read -r path existed bakname; do
    # Always remove current WV-managed file first (safe: these are WV-owned paths)
    rm -f "$path" 2>/dev/null || true

    if [[ "$existed" == "1" ]]; then
      # Restore original version if we have it
      if [[ -f "$snap/$bakname" ]]; then
        mkdir -p "$(dirname "$path")" || true
        cp -a "$snap/$bakname" "$path" 2>/dev/null || true
      fi
    fi
  done < "$manifest"

  log "OK" "Restore complete from snapshot: $snap"
}

write_hook_and_policies() {
  if $DRY_RUN; then
    log "DRY" "Would ensure dirs: $HOOK_DIR, $APT_CONF_DIR, $WV_ETC_DIR"
    log "DRY" "Would write hook: $HOOK_SCRIPT"
    log "DRY" "Would write APT snippet: $APT_CONF_DIR/99-preinstall-filter"
    log "DRY" "Would write no-recommends: $APT_CONF_DIR/99-no-recommends-suggests"
    log "DRY" "Would write https-only: $APT_CONF_DIR/99-apt-https-only"
    return 0
  fi

  mkdir -p "$HOOK_DIR" "$APT_CONF_DIR" "$WV_ETC_DIR" "$LOG_DIR"
  chmod 755 "$HOOK_DIR" || true
  chmod 700 "$WV_ETC_DIR" || true
  chmod 700 "$LOG_DIR" || true

  # Hook script: robust enough for both "VERSION 1" (deb paths) and "VERSION 2" formats.
  cat > "$HOOK_SCRIPT" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="/var/log/whitevenom"
LOGFILE="$LOG_DIR/apt-preinstall.log"
WV_ETC_DIR="/etc/whitevenom"
BYPASS_FILE="$WV_ETC_DIR/apt_hook_bypass"

BLACKLIST=(
  systemd
  systemd-sysv
  systemd-timesyncd
  systemd-resolved
  libsystemd0
  libsystemd-journal0
  libsystemd-shared
)

ts() { date +"%Y-%m-%d %H:%M:%S"; }

mkdir -p "$LOG_DIR" 2>/dev/null || true
chmod 700 "$LOG_DIR" 2>/dev/null || true

if [[ -f "$BYPASS_FILE" ]]; then
  echo "$(ts) [WV_APT_HOOK/BYPASS] $BYPASS_FILE present -> allowing install." | tee -a "$LOGFILE" >&2
  exit 0
fi

match_blacklist() {
  local s="$1"
  local b
  for b in "${BLACKLIST[@]}"; do
    # token-ish match to reduce false positives
    if [[ "$s" == *"$b"* ]]; then
      echo "$b"
      return 0
    fi
  done
  return 1
}

pkg_from_deb_name() {
  # Try to extract package name from ".../name_version_arch.deb"
  local deb="$1"
  deb="${deb##*/}"
  deb="${deb%.deb}"
  # name_version_arch (split on first underscore)
  if [[ "$deb" == *"_"* ]]; then
    printf "%s" "${deb%%_*}"
  else
    printf "%s" "$deb"
  fi
}

exit_code=0
while IFS= read -r line; do
  [[ -z "$line" ]] && continue

  # Ignore protocol headers
  if [[ "$line" == VERSION* ]]; then
    continue
  fi

  # Candidate strings to inspect
  cand1="$line"
  cand2="${line##*/}"
  cand3=""
  if [[ "$line" == *.deb* ]]; then
    cand3="$(pkg_from_deb_name "$line")"
  fi

  for c in "$cand1" "$cand2" "$cand3"; do
    [[ -z "$c" ]] && continue
    m="$(match_blacklist "$c" || true)"
    if [[ -n "${m:-}" ]]; then
      echo "$(ts) [WV_APT_HOOK/BLOCK] Blacklist match: '$m' in '$line'" | tee -a "$LOGFILE" >&2
      exit_code=1
      break
    fi
  done
done

exit "$exit_code"
EOS
  chmod 755 "$HOOK_SCRIPT"

  # APT snippet to call the hook
  cat > "$APT_CONF_DIR/99-preinstall-filter" <<EOF
DPkg::Pre-Install-Pkgs {
  "$HOOK_SCRIPT";
};
EOF

  # No recommends/suggests
  cat > "$APT_CONF_DIR/99-no-recommends-suggests" <<'EOF'
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF

  # HTTPS-only (fail-closed), with sane retries
  cat > "$APT_CONF_DIR/99-apt-https-only" <<'EOF'
Acquire::Retries "3";
Acquire::AllowInsecureRepositories "false";
Acquire::https::Verify-Peer "true";
Acquire::https::Verify-Host "true";
EOF

  log "INFO" "Hook + policies installed. Blacklist: ${BLACKLIST[*]}"
  log "INFO" "Hook bypass file (if needed): $BYPASS_FILE"
}

optional_toolchain_sanity() {
  log "INFO" "Toolchain sanity: dpkg-dev + build-essential (non-fatal)."

  if $DRY_RUN; then
    log "DRY" "Would run: apt-get update"
    log "DRY" "Would run: apt-get install -y --no-install-recommends dpkg-dev build-essential"
    return 0
  fi

  # Avoid failing the whole module due to transient network/repo issues.
  if ! apt-get update; then
    log "WARN" "apt-get update failed; skipping toolchain install (APT policies remain applied)."
    return 0
  fi

  if ! apt-get install -y --no-install-recommends dpkg-dev build-essential; then
    log "WARN" "Toolchain install failed; continuing (APT policies remain applied)."
    return 0
  fi

  log "OK" "Toolchain OK (dpkg-dev/build-essential)."
}

log "INFO" "Mode: $MODE"
log "INFO" "Snapshot root: $SNAPSHOT_ROOT"

case "$MODE" in
  --restore)
    restore_from_snapshot
    exit 0
    ;;
  --dry-run|--apply)
    :
    ;;
esac

# Snapshot first, then write policies/hook.
make_snapshot
write_hook_and_policies
optional_toolchain_sanity

log "OK" "05 modul kész."
exit 0
