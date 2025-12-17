#!/usr/bin/env bash
# 04_ipv6_worm_protection.sh (v2 redesign)
# White Venom – RA/MAC Guard (integrated into 04 as requested)
#
# Design decision:
# - No sysctl here (sysctl is owned by 00 + reconciliation).
# - No full ip6tables-restore here (03 owns baseline firewall).
# - This module injects a dedicated chain to filter *Router Advertisements only* (ICMPv6 type 134),
#   so it does not clobber the rest of the firewall.
#
# Env (sensitive, DO NOT hardcode):
#   WV_IFACE              (required) e.g. wlo1
#   WV_EXPECTED_MAC       (optional) expected MAC of WV_IFACE
#   WV_RA_ALLOW_MACS      (optional) allow router MAC(s), comma/space-separated
#   WV_RA_ALLOW_LLADDRS   (optional) allow router IPv6 link-local(s), comma/space-separated
#   WV_RA_SNIFF_SECONDS   (optional) audit-only tcpdump sniff seconds (if tcpdump exists)
#
# Usage:
#   ./04_ipv6_worm_protection.sh --audit
#   ./04_ipv6_worm_protection.sh --dry-run
#   ./04_ipv6_worm_protection.sh --apply
#   ./04_ipv6_worm_protection.sh --restore

set -euo pipefail

SCRIPT="04_RA_GUARD"
TS() { date +"%Y-%m-%d %H:%M:%S"; }
log() { local lvl="$1"; shift; printf "%s [%s/%s] %s\n" "$(TS)" "$SCRIPT" "$lvl" "$*"; }
die() { log "FATAL" "$*"; exit 1; }

MODE="audit"   # audit | dry-run | apply | restore

have() { command -v "$1" >/dev/null 2>&1; }
norm_list() { tr ', ' '\n\n' | sed '/^[[:space:]]*$/d'; }

run() {
  local cmd="$*"
  if [[ "$MODE" == "dry-run" ]]; then
    log "DRY" "$cmd"
  else
    log "ACTION" "$cmd"
    eval "$cmd"
  fi
}

has_v6_default_route() {
  ip -6 route show default 2>/dev/null | grep -q .
}

require_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Root required (sudo)."; }

: "${WV_IFACE:=}"
require_iface() {
  [[ -n "$WV_IFACE" ]] || die "WV_IFACE required (export WV_IFACE=wlo1)."
  [[ -d "/sys/class/net/${WV_IFACE}" ]] || die "Interface not found: $WV_IFACE"
}

iface_mac() { cat "/sys/class/net/${WV_IFACE}/address" 2>/dev/null | tr 'A-Z' 'a-z' || true; }

IP6T="/usr/sbin/ip6tables"; [[ -x "$IP6T" ]] || IP6T="$(command -v ip6tables || true)"
[[ -n "$IP6T" ]] || die "ip6tables not found."

ip6() { $IP6T "$@"; }

chain_exists() { ip6 -S "$1" >/dev/null 2>&1; }

mac_match_supported() {
  # nft wrapper usually supports -m mac, but verify
  ip6 -m mac -h >/dev/null 2>&1
}

audit() {
  log "INFO" "Audit snapshot: iface=$WV_IFACE"
  ip -br link show dev "$WV_IFACE" || true
  ip -6 -br addr show dev "$WV_IFACE" || true
  ip -6 route show default || true
  ip -6 neigh show dev "$WV_IFACE" || true

  local exp="${WV_EXPECTED_MAC:-}"
  if [[ -n "$exp" ]]; then
    exp="$(printf "%s" "$exp" | tr 'A-Z' 'a-z')"
    local act; act="$(iface_mac)"
    if [[ "$act" == "$exp" ]]; then
      log "OK" "MAC matches expected ($exp)"
    else
      log "WARN" "MAC mismatch: actual=$act expected=$exp"
    fi
  else
    log "INFO" "WV_EXPECTED_MAC not set; skipping MAC check."
  fi

  if ip6 -C INPUT -i "$WV_IFACE" -p ipv6-icmp --icmpv6-type router-advertisement -j WV_RA_GUARD 2>/dev/null; then
    log "OK" "INPUT hook present -> WV_RA_GUARD"
  else
    log "INFO" "INPUT hook not present."
  fi

  if chain_exists WV_RA_GUARD; then
    log "INFO" "WV_RA_GUARD chain exists:"
    ip6 -S WV_RA_GUARD || true
  else
    log "INFO" "WV_RA_GUARD chain not present."
  fi

  local sniff="${WV_RA_SNIFF_SECONDS:-0}"
  if [[ "$sniff" =~ ^[0-9]+$ ]] && [[ "$sniff" -gt 0 ]] && have tcpdump; then
    log "INFO" "tcpdump RA sniff for ${sniff}s (audit-only)..."
    timeout "${sniff}" tcpdump -i "$WV_IFACE" -nn -vv "icmp6 and ip6[40]=134" -c 10 || true
  fi
}

apply_guard() {
  local allow_macs_raw allow_ll_raw
  allow_macs_raw="${WV_RA_ALLOW_MACS:-}"
  allow_ll_raw="${WV_RA_ALLOW_LLADDRS:-}"

  # Normalize lists (split on comma/space)
  local allow_macs allow_ll
  allow_macs="$(printf "%s" "$allow_macs_raw" | norm_list || true)"
  allow_ll="$(printf "%s" "$allow_ll_raw" | norm_list || true)"

  if [[ -z "$allow_macs" && -z "$allow_ll" ]]; then
    die "Allowlist empty. Set WV_RA_ALLOW_MACS and/or WV_RA_ALLOW_LLADDRS before --apply."
  fi

  # ---- Validate inputs BEFORE touching ip6tables ----
  local bad=0

  validate_mac() {
    local m="$1"
    [[ "$m" =~ ^([0-9a-f]{2}:){5}[0-9a-f]{2}$ ]]
  }

  validate_lladdr() {
    local a="$1"
    # Prefer python ipaddress if available for robust validation.
    if command -v python3 >/dev/null 2>&1; then
      python3 - <<'PY' "$a"
import ipaddress,sys
a=sys.argv[1]
try:
  ip=ipaddress.IPv6Address(a)
except Exception:
  sys.exit(1)
# enforce link-local only (fe80::/10)
if not ip.is_link_local:
  sys.exit(2)
sys.exit(0)
PY
      return $?
    fi
    # Fallback: cheap checks
    [[ "$a" == fe80:* || "$a" == FE80:* ]]
  }

  if [[ -n "$allow_macs" ]]; then
    while IFS= read -r mac; do
      mac="$(printf "%s" "$mac" | tr 'A-Z' 'a-z')"
      [[ -z "$mac" ]] && continue
      if ! validate_mac "$mac"; then
        log "FATAL" "Invalid MAC in WV_RA_ALLOW_MACS: '$mac' (expected aa:bb:cc:dd:ee:ff)"
        bad=1
      fi
    done <<<"$allow_macs"
  fi

  if [[ -n "$allow_ll" ]]; then
    while IFS= read -r ll; do
      [[ -z "$ll" ]] && continue
      validate_lladdr "$ll"
      rc=$?
      if [[ $rc -ne 0 ]]; then
        if [[ $rc -eq 2 ]]; then
          log "FATAL" "WV_RA_ALLOW_LLADDRS must be link-local (fe80::/10). Got: '$ll'"
        else
          log "FATAL" "Invalid IPv6 address in WV_RA_ALLOW_LLADDRS: '$ll'"
        fi
        bad=1
      fi
    done <<<"$allow_ll"
  fi

  [[ $bad -eq 0 ]] || die "Refusing to apply RA guard due to invalid allowlist."

  log "INFO" "Applying WV_RA_GUARD for iface=$WV_IFACE (RA only)."

  # ip6tables wait flag if supported
  local WFLAG=""
  if $IP6T -h 2>/dev/null | grep -q -- '-w'; then
    WFLAG="-w"
  fi

  # Create/flush chain
  if chain_exists WV_RA_GUARD; then
    run "$IP6T $WFLAG -F WV_RA_GUARD"
  else
    run "$IP6T $WFLAG -N WV_RA_GUARD"
  fi

  # Allow by MAC (if supported)
  if [[ -n "$allow_macs" ]]; then
    if mac_match_supported; then
      while IFS= read -r mac; do
        mac="$(printf "%s" "$mac" | tr 'A-Z' 'a-z')"
        [[ -z "$mac" ]] && continue
        run "$IP6T $WFLAG -A WV_RA_GUARD -i '$WV_IFACE' -p ipv6-icmp --icmpv6-type router-advertisement -m mac --mac-source '$mac' -j ACCEPT"
      done <<<"$allow_macs"
    else
      log "WARN" "ip6tables -m mac not supported here; ignoring WV_RA_ALLOW_MACS."
    fi
  fi

  # Allow by link-local source
  if [[ -n "$allow_ll" ]]; then
    while IFS= read -r ll; do
      [[ -z "$ll" ]] && continue
      run "$IP6T $WFLAG -A WV_RA_GUARD -i '$WV_IFACE' -p ipv6-icmp --icmpv6-type router-advertisement -s '$ll' -j ACCEPT"
    done <<<"$allow_ll"
  fi

  # Log + drop everything else
  run "$IP6T $WFLAG -A WV_RA_GUARD -i '$WV_IFACE' -p ipv6-icmp --icmpv6-type router-advertisement -j LOG --log-prefix 'WV_RA_DROP ' --log-level 4"
  run "$IP6T $WFLAG -A WV_RA_GUARD -i '$WV_IFACE' -p ipv6-icmp --icmpv6-type router-advertisement -j DROP"

  # Hook into INPUT early
  if ip6 -C INPUT -i "$WV_IFACE" -p ipv6-icmp --icmpv6-type router-advertisement -j WV_RA_GUARD 2>/dev/null; then
    log "INFO" "INPUT already jumps to WV_RA_GUARD for RA on $WV_IFACE."
  else
    run "$IP6T $WFLAG -I INPUT 1 -i '$WV_IFACE' -p ipv6-icmp --icmpv6-type router-advertisement -j WV_RA_GUARD"
  fi

  log "OK" "RA guard applied."
}

restore_guard() {
  log "INFO" "Restoring WV_RA_GUARD (remove hook + chain)."

  # Remove any INPUT jumps to WV_RA_GUARD for RA, regardless of interface
  local WFLAG=""
  if $IP6T -h 2>/dev/null | grep -q -- '-w'; then
    WFLAG="-w"
  fi

  # Find matching rules and delete them deterministically
  while true; do
    local line
    line="$($IP6T -S INPUT 2>/dev/null | grep -E -- " -p ipv6-icmp .*--icmpv6-type router-advertisement .* -j WV_RA_GUARD" | head -n 1 || true)"
    [[ -z "$line" ]] && break
    # Convert "-A INPUT ..." -> "-D INPUT ..."
    local del
    del="$(printf "%s" "$line" | sed -E 's/^-A /-D /')"
    run "$IP6T $WFLAG $del"
  done

  if chain_exists WV_RA_GUARD; then
    run "$IP6T $WFLAG -F WV_RA_GUARD"
    run "$IP6T $WFLAG -X WV_RA_GUARD"
  fi

  log "OK" "RA guard restored."
}

usage() {
  cat <<EOF
Usage: $0 --audit | --dry-run | --apply | --restore

Env:
  WV_IFACE (required)
  WV_EXPECTED_MAC (optional)
  WV_RA_ALLOW_MACS (optional)
  WV_RA_ALLOW_LLADDRS (optional)
EOF
  exit 1
}

# --- arg parsing ---
# Notes about sudo/env:
# - sudo often drops environment variables. Prefer:
#     sudo env WV_IFACE=wlo1 WV_RA_ALLOW_LLADDRS="fe80::...." ./04... --apply
#
# Modes:
#   --audit    : status only
#   --dry-run  : show what would happen (decision + planned ip6tables ops)
#   --apply    : AUTO behavior:
#                 - If no IPv6 default route: ensure guard OFF (restore) and exit 0
#                 - If IPv6 default route present:
#                     - If allowlist present and WV_IFACE set -> apply guard
#                     - Else -> warn and leave guard OFF (or fail if WV_RA_STRICT=1)
#   --restore  : force remove guard (best effort)

WV_RA_STRICT="${WV_RA_STRICT:-0}"  # 1 => fail if V6 default route is present but prerequisites are missing

case "${1:-}" in
  --audit|"") MODE="audit" ;;
  --dry-run) MODE="dry-run" ;;
  --apply) MODE="apply" ;;
  --restore) MODE="restore" ;;
  -h|--help) usage ;;
  *) die "Unknown arg: $1" ;;
esac

require_root

log "INFO" "Mode: --$MODE"

case "$MODE" in
  audit)
    # If iface isn't set, audit still prints nothing destructive.
    if [[ -z "${WV_IFACE:-}" ]]; then
      log "WARN" "WV_IFACE not set; audit will be limited. (Hint: sudo env WV_IFACE=wlo1 $0 --audit)"
    else
      require_iface
    fi
    audit
    ;;

  restore)
    # restore does not require iface (we delete any WV_RA_GUARD hook lines).
    restore_guard
    ;;

  dry-run)
    # Decision preview
    if has_v6_default_route; then
      log "INFO" "IPv6 default route detected -> V6_NATIVE behavior."
    else
      log "INFO" "No IPv6 default route -> LEGACY_UPLINK behavior (guard OFF)."
    fi

    if ! has_v6_default_route; then
      restore_guard
      log "INFO" "Dry-run complete (legacy: would keep RA guard OFF)."
      exit 0
    fi

    # V6_NATIVE: need iface + allowlist
    if [[ -z "${WV_IFACE:-}" ]]; then
      if [[ "$WV_RA_STRICT" == "1" ]]; then
        die "V6 default route present but WV_IFACE missing (strict)."
      fi
      log "WARN" "V6 default route present but WV_IFACE missing -> would SKIP apply (guard OFF)."
      exit 0
    fi
    require_iface

    if [[ -z "${WV_RA_ALLOW_MACS:-}" && -z "${WV_RA_ALLOW_LLADDRS:-}" ]]; then
      if [[ "$WV_RA_STRICT" == "1" ]]; then
        die "V6 default route present but allowlist missing (strict)."
      fi
      log "WARN" "V6 default route present but allowlist missing -> would SKIP apply (guard OFF)."
      exit 0
    fi

    audit
    apply_guard
    log "INFO" "Dry-run complete (v6-native: would apply guard)."
    ;;

  apply)
    # AUTO behavior for orchestrator: safe-by-default, no branching outside.
    if ! has_v6_default_route; then
      log "INFO" "No IPv6 default route -> ensuring RA guard OFF."
      restore_guard
      exit 0
    fi

    # V6 default route exists. Either apply guard (if configured) or warn/strict-fail.
    if [[ -z "${WV_IFACE:-}" ]]; then
      if [[ "$WV_RA_STRICT" == "1" ]]; then
        die "V6 default route present but WV_IFACE missing (strict)."
      fi
      log "WARN" "V6 default route present but WV_IFACE missing -> leaving RA guard OFF."
      exit 0
    fi
    require_iface

    if [[ -z "${WV_RA_ALLOW_MACS:-}" && -z "${WV_RA_ALLOW_LLADDRS:-}" ]]; then
      if [[ "$WV_RA_STRICT" == "1" ]]; then
        die "V6 default route present but allowlist missing (strict)."
      fi
      log "WARN" "V6 default route present but allowlist missing -> leaving RA guard OFF."
      exit 0
    fi

    apply_guard
    ;;
esac
