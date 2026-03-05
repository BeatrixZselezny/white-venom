#!/usr/bin/env bash
# 03_sysctl_ip6tables-security.sh (v2 redesign)
# White Venom – IPv6 firewall baseline (ip6tables) only.
#
# Design decision:
# - sysctl is owned by 00_install + final-authority reconciliation.
# - This module owns the baseline IPv6 firewall ruleset application + backups.
# - RA/MAC allowlisting is handled by 04 (WV_RA_GUARD) as an incremental chain injection.

set -euo pipefail

SCRIPT="03_IP6TABLES_BASELINE"
TS() { date +"%Y-%m-%d %H:%M:%S"; }
log() { local lvl="$1"; shift; printf "%s [%s/%s] %s\n" "$(TS)" "$SCRIPT" "$lvl" "$*"; }
die() { log "FATAL" "$*"; exit 1; }

MODE="--dry-run"     # --dry-run | --apply
DRY=true

# Absolute-safe script dir
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source rules file (repo) and destination rules file (system)
RULES_SRC_DEFAULT="${SCRIPT_DIR}/firewall/whitevenom_baseline.v6"
RULES_SRC="${WV_IP6TABLES_RULES_SRC:-$RULES_SRC_DEFAULT}"
RULES_DST="/etc/ip6tables/rules.v6"

BACKUP_ROOT="/var/backups/skell_backups/03_ip6tables"
STAMP="$(date +%Y%m%d-%H%M%S)"
BKP_RULES="${BACKUP_ROOT}/rules.v6.bak.${STAMP}"
BKP_SAVE="${BACKUP_ROOT}/ip6tables.before.${STAMP}"

have() { command -v "$1" >/dev/null 2>&1; }

# prefer absolute tools
IP6T="/usr/sbin/ip6tables"; [[ -x "$IP6T" ]] || IP6T="$(command -v ip6tables || true)"
IP6TS="/usr/sbin/ip6tables-save"; [[ -x "$IP6TS" ]] || IP6TS="$(command -v ip6tables-save || true)"
IP6TR="/usr/sbin/ip6tables-restore"; [[ -x "$IP6TR" ]] || IP6TR="$(command -v ip6tables-restore || true)"

run() {
  if $DRY; then
    log "DRY" "$*"
  else
    log "ACTION" "$*"
    "$@"
  fi
}

run_sh() {
  local cmd="$1"
  if $DRY; then
    log "DRY" "$cmd"
  else
    log "ACTION" "$cmd"
    bash -c "$cmd"
  fi
}

usage() {
  cat <<EOF
Usage: $0 [--dry-run|--apply]

Env:
  WV_IP6TABLES_RULES_SRC   Optional absolute path to baseline rules file (ip6tables-restore format).
Default:
  $RULES_SRC_DEFAULT

EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) MODE="--dry-run"; DRY=true; shift ;;
    --apply)   MODE="--apply";   DRY=false; shift ;;
    -h|--help) usage ;;
    *) die "Unknown arg: $1" ;;
  esac
done

[[ $EUID -eq 0 ]] || die "Root required (sudo)."
[[ -n "$IP6T" && -n "$IP6TS" && -n "$IP6TR" ]] || die "ip6tables toolchain missing."

log "INFO" "Mode: $MODE"
log "INFO" "Rules src: $RULES_SRC"
log "INFO" "Rules dst: $RULES_DST"

[[ -f "$RULES_SRC" ]] || die "Rules source file not found: $RULES_SRC"

if $DRY; then
  log "INFO" "Preview rules (first 80 lines):"
  nl -ba "$RULES_SRC" | sed -n '1,80p' | sed 's/^/  /'
  log "INFO" "Dry-run complete."
  exit 0
fi

# Apply
run mkdir -p "$BACKUP_ROOT"
run chmod 700 "$BACKUP_ROOT"

# Backup current rules file if present
if [[ -f "$RULES_DST" ]]; then
  run cp -a "$RULES_DST" "$BKP_RULES"
  log "INFO" "Backup rules.v6 -> $BKP_RULES"
fi

# Backup current ip6tables state
run_sh "\"$IP6TS\" > \"$BKP_SAVE\""
log "INFO" "Backup ip6tables-save -> $BKP_SAVE"

# Install rules file (system)
run mkdir -p "$(dirname "$RULES_DST")"
run cp -a "$RULES_SRC" "$RULES_DST"

# Apply via ip6tables-restore (best-effort wait for lock if supported)
if "$IP6TR" -h 2>/dev/null | grep -q -- '-w'; then
  run_sh "\"$IP6TR\" -w < \"$RULES_DST\""
else
  run_sh "\"$IP6TR\" < \"$RULES_DST\""
fi

log "OK" "Baseline IPv6 firewall applied."

# Optional persist (best-effort; does not assume init system)
if have netfilter-persistent; then
  log "INFO" "Persisting with netfilter-persistent (best effort)."
  netfilter-persistent save || true
fi

log "INFO" "03 complete. Backups: $BACKUP_ROOT"
exit 0
