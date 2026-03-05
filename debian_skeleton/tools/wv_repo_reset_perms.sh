#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  wv_repo_reset_perms.sh [--apply|--dry-run] [--repo <path>] [--user <name>] [--group <name>]

Defaults:
  --dry-run
  --repo: git toplevel (or current dir if not a git repo)
  --user/--group: original user running sudo (SUDO_USER); fallback: USER (if not root)

Notes:
  - Excludes .git/ from chmod normalization (ownership is still fixed).
  - Sets dirs 755, *.sh 755, other files 644, removes group/world write bits.
EOF
}

MODE="dry"
REPO=""
TARGET_USER=""
TARGET_GROUP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) MODE="apply"; shift ;;
    --dry-run) MODE="dry"; shift ;;
    --repo) REPO="${2:-}"; shift 2 ;;
    --user) TARGET_USER="${2:-}"; shift 2 ;;
    --group) TARGET_GROUP="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

# If not root, re-run with sudo (keeps SUDO_USER)
if [[ "${EUID}" -ne 0 ]]; then
  exec sudo -E "$0" ${MODE/"/"/} --"${MODE}" ${REPO:+--repo "$REPO"} ${TARGET_USER:+--user "$TARGET_USER"} ${TARGET_GROUP:+--group "$TARGET_GROUP"}
fi

# Determine repo root
if [[ -z "$REPO" ]]; then
  REPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi

# Determine target user/group
if [[ -z "$TARGET_USER" ]]; then
  TARGET_USER="${SUDO_USER:-${USER:-}}"
fi
if [[ -z "$TARGET_GROUP" ]]; then
  TARGET_GROUP="$TARGET_USER"
fi

if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
  echo "[WV/ERR] Refusing to chown repo to root. Run as normal user or pass --user debiana." >&2
  exit 1
fi

run() {
  if [[ "$MODE" == "apply" ]]; then
    echo "[WV/APPLY] $*"
    eval "$@"
  else
    echo "[WV/DRY]   $*"
  fi
}

echo "[WV/INFO] Repo:  $REPO"
echo "[WV/INFO] Owner: $TARGET_USER:$TARGET_GROUP"
echo "[WV/INFO] Mode:  --$MODE"

# Ownership: include .git as well (prevents 'dubious ownership' issues)
run "chown -R ${TARGET_USER}:${TARGET_GROUP} \"${REPO}\""

# Permissions: exclude .git from chmod normalization
run "find \"${REPO}\" -path \"${REPO}/.git\" -prune -o -type d -print0 | xargs -0 chmod 755"
run "find \"${REPO}\" -path \"${REPO}/.git\" -prune -o -type f -name '*.sh' -print0 | xargs -0 chmod 755"
run "find \"${REPO}\" -path \"${REPO}/.git\" -prune -o -type f ! -name '*.sh' -print0 | xargs -0 chmod 644"

# Remove group/world write bits (exclude .git)
run "find \"${REPO}\" -path \"${REPO}/.git\" -prune -o -print0 | xargs -0 chmod go-w"

echo "[WV/OK] Repo permissions/ownership normalized."

