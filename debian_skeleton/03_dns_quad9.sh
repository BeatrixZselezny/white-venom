#!/bin/bash
# branches/03_dns_quad9.sh
# Configure system-wide IPv6 DNS with Quad9, disable mDNS if requested
# Author: Beatrix Zelezny 🐱 2025
set -euo pipefail

RESOLV_CONF="/etc/resolv.conf"
NSSWITCH="/etc/nsswitch.conf"
IP6TABLES_BIN="/sbin/ip6tables"
BACKUP_DIR="${BRANCH_BACKUP_DIR:-/tmp/branch_backup_03}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
DRY_RUN=true
DISABLE_MDNS=false

usage() {
  echo "Usage: $0 [--apply|--dry-run] [--no-mdns]"
  echo "  --apply    : Apply configuration"
  echo "  --dry-run  : Preview only (default)"
  echo "  --no-mdns  : Block multicast DNS (UDP/5353 ff02::fb)"
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --apply) DRY_RUN=false; shift;;
    --dry-run) DRY_RUN=true; shift;;
    --no-mdns) DISABLE_MDNS=true; shift;;
    *) usage;;
  esac
done

[ "$(id -u)" -eq 0 ] || { echo "Run as root"; exit 2; }

echo "Mode: $( $DRY_RUN && echo DRY-RUN || echo APPLY )"
echo "Disable mDNS: $( $DISABLE_MDNS && echo YES || echo NO )"

# Quad9 IPv6 nameservers
read -r -d '' RESOLV <<'EOF' || true
# Quad9 IPv6 DNS (secure, non-logging)
nameserver 2620:fe::fe
nameserver 2620:fe::9
options edns0 trust-ad
EOF

# Update /etc/nsswitch.conf to prefer dns over mdns
read -r -d '' NSS_REPLACE <<'EOF' || true
hosts:          files dns [NOTFOUND=return]
EOF

# ip6tables mDNS block rule
MDNS_RULE="$IP6TABLES_BIN -A INPUT -p udp -d ff02::fb --dport 5353 -j DROP"

echo "===== resolv.conf PREVIEW ====="
echo "$RESOLV"
echo
echo "===== nsswitch.conf PREVIEW (hosts line only) ====="
echo "$NSS_REPLACE"
echo
if $DISABLE_MDNS; then
  echo "===== mDNS ip6tables rule ====="
  echo "$MDNS_RULE"
fi

if $DRY_RUN; then
  echo "[DRY RUN] No changes made."
  exit 0
fi

echo "[APPLY] Backing up existing configs..."
mkdir -p "$BACKUP_DIR"
cp -a "$RESOLV_CONF" "$BACKUP_DIR/resolv.conf.$TIMESTAMP" 2>/dev/null || true
cp -a "$NSSWITCH" "$BACKUP_DIR/nsswitch.conf.$TIMESTAMP" 2>/dev/null || true

echo "$RESOLV" > "$RESOLV_CONF"

# patch nsswitch.conf
if grep -q '^hosts:' "$NSSWITCH"; then
  sed -i 's/^hosts:.*/hosts:          files dns [NOTFOUND=return]/' "$NSSWITCH"
else
  echo "$NSS_REPLACE" >> "$NSSWITCH"
fi

# disable mDNS if requested
if $DISABLE_MDNS; then
  $MDNS_RULE || true
  echo "[APPLY] mDNS (ff02::fb) traffic blocked via ip6tables"
fi

echo "[APPLY COMPLETE] Quad9 IPv6 DNS configured system-wide."
echo "Check with: dig -6 @2620:fe::fe google.com AAAA"
