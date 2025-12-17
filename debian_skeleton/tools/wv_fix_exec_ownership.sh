#!/usr/bin/env bash
set -euo pipefail

# wv_fix_exec_ownership.sh (FIXED)
# Bin-only ownership + perms restore, without clobbering exec bits.
#
# Usage:
#   sudo /ABS/.../wv_fix_exec_ownership.sh --dry-run --path /ABS/PATH [--path /ABS/PATH2 ...]
#   sudo /ABS/.../wv_fix_exec_ownership.sh --apply   --path /ABS/PATH [--path /ABS/PATH2 ...]
#
# Optional:
#   --user debiana --group debiana

MODE=""
TARGET_USER="debiana"
TARGET_GROUP="debiana"
PATHS=()

log(){ printf '%s\n' "$*"; }
die(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }

need_root(){
  if [[ "${EUID}" -ne 0 ]]; then
    die "Run as root (use sudo)."
  fi
}

run(){
  if [[ "${MODE}" == "--dry-run" ]]; then
    log "[DRY] $*"
  else
    eval "$@"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|--apply) MODE="$1"; shift ;;
    --user) TARGET_USER="$2"; shift 2 ;;
    --group) TARGET_GROUP="$2"; shift 2 ;;
    --path) PATHS+=("$2"); shift 2 ;;
    -h|--help)
      cat <<EOF2
Usage:
  sudo $0 --dry-run|--apply --path /ABS/PATH [--path /ABS/PATH2 ...]
Options:
  --user  <name>   default: debiana
  --group <name>   default: debiana
EOF2
      exit 0
      ;;
    *) die "Unknown arg: $1" ;;
  esac
done

[[ -n "${MODE}" ]] || die "Missing mode: --dry-run or --apply"
[[ "${#PATHS[@]}" -ge 1 ]] || die "Missing at least one --path /ABS/PATH"
need_root

for p in "${PATHS[@]}"; do
  [[ "${p}" == /* ]] || die "--path must be absolute: ${p}"
  [[ -e "${p}" ]] || die "Path does not exist: ${p}"

  log "== Processing: ${p}"
  log "   -> owner: ${TARGET_USER}:${TARGET_GROUP}"

  # 1) Ownership back to user (recursive)
  run "chown -R '${TARGET_USER}:${TARGET_GROUP}' '${p}'"

  # 2) Directories: 0755
  run "find '${p}' -type d -print0 | xargs -0r chmod 0755"

  # 3) Shell scripts: 0755
  run "find '${p}' -type f \\( -name '*.sh' -o -name '*.bash' \\) -print0 | xargs -0r chmod 0755"

  # 4) Any already-executable regular file stays executable: 0755
  # IMPORTANT: we do NOT mass-chmod files to 0644 before this.
  run "find '${p}' -type f -perm /111 -print0 | xargs -0r chmod 0755"

  # 5) Remaining non-executable regular files -> 0644
  run "find '${p}' -type f ! -perm /111 ! \\( -name '*.sh' -o -name '*.bash' \\) -print0 | xargs -0r chmod 0644"

  log "== OK: ${p}"
done

log "Done."
