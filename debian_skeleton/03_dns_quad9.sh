#!/bin/bash
# branches/03_dns_quad9.sh
# Configure local Unbound forwarding to Quad9 (IPv6), enable DNSSEC, optionally block mDNS.
# Usage:
#   sudo ./03_dns_quad9.sh --dry-run [--no-mdns] [--allow-ra]
#   sudo ./03_dns_quad9.sh --apply   [--no-mdns] [--allow-ra]
#
set -euo pipefail

# CONFIG
UNBOUND_CONF_DIR="/etc/unbound/unbound.conf.d"
UNBOUND_MAIN="/etc/unbound/unbound.conf"
LOCAL_RESOLV="/etc/resolv.conf"
BACKUP_DIR="${BRANCH_BACKUP_DIR:-/tmp/branch_backup_03}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
DRY_RUN=true
DISABLE_MDNS=false
ALLOW_RA=false   # if true, allow RA on detected iface (for SLAAC to function)

# Quad9 IPv6 addresses (keep updated if Quad9 changes)
QUAD9_AAAA1="2620:fe::fe"
QUAD9_AAAA2="2620:fe::9"

usage() {
  cat <<EOF
Usage: $0 [--apply|--dry-run] [--no-mdns] [--allow-ra]
  --apply    : Apply changes
  --dry-run  : Preview (default)
  --no-mdns  : Block mDNS (multicast DNS) IPv6 traffic (ff02::fb UDP/5353)
  --allow-ra : Allow Router Advertisements (RA) on the active interface (enable SLAAC)
EOF
  exit 1
}

# parse args
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) DRY_RUN=false; shift;;
    --dry-run) DRY_RUN=true; shift;;
    --no-mdns) DISABLE_MDNS=true; shift;;
    --allow-ra) ALLOW_RA=true; shift;;
    -h|--help) usage;;
    *) echo "Unknown arg: $1"; usage;;
  esac
done

[ "$(id -u)" -eq 0 ] || { echo "Run as root"; exit 2; }

# detect IPv6 interface that likely is hotspot (if needed for RA decisions)
IFACE=$(ip -6 route show default 2>/dev/null | awk '/default/ {for(i=1;i<=NF;i++) if ($i=="dev"){print $(i+1); exit}}' || true)
if [ -z "$IFACE" ]; then
  IFACE=$(ip -6 addr show scope global | awk '/^[0-9]+:/{iface=$2} /inet6/ && /scope global/ {gsub(/:$/,"",iface); print iface; exit}')
fi

echo "Detected IPv6 interface: ${IFACE:-(none)}"
echo "Mode: $( $DRY_RUN && echo DRY-RUN || echo APPLY )"
echo "Disable mDNS: $DISABLE_MDNS"
echo "Allow RA on interface (SLAAC): $ALLOW_RA"

# Unbound minimal secure forwarder config (forward to Quad9 via IPv6)
read -r -d '' UNBOUND_QUAD9 <<'EOF' || true
server:
    verbosity: 1
    interface: 127.0.0.1
    interface: ::1
    access-control: 127.0.0.0/8 allow
    access-control: ::1/128 allow
    do-ip4: no
    do-ip6: yes
    do-udp: yes
    do-tcp: yes
    outgoing-interface: ::0
    msg-cache-size: 50m
    rrset-cache-size: 100m
    cache-min-ttl: 3600
    cache-max-ttl: 86400
    hide-identity: yes
    hide-version: yes
    qname-minimisation: yes
    harden-short-buffers: yes
    module-config: "validator iterator"
    auto-trust-anchor-file: "/var/lib/unbound/root.key"
    tls-cert-bundle: "/etc/ssl/certs/ca-certificates.crt"

forward-zone:
    name: "."
    forward-addr: 2620:fe::fe
    forward-addr: 2620:fe::9
EOF

# /etc/resolv.conf to point to local Unbound (only localhost)
read -r -d '' RESOLV_LOCAL <<'EOF' || true
# /etc/resolv.conf - pointed to local Unbound
nameserver 127.0.0.1
nameserver ::1
options edns0 trust-ad
EOF

# mDNS ip6tables rule (block ff02::fb UDP/5353)
IP6TABLES="/sbin/ip6tables"
MDNS_RULE="$IP6TABLES -A INPUT -p udp -d ff02::fb --dport 5353 -j DROP"

echo "===== Unbound config preview ====="
echo "$UNBOUND_QUAD9" | sed 's/^/  /'
echo
echo "===== resolv.conf preview ====="
echo "$RESOLV_LOCAL" | sed 's/^/  /'
if $DISABLE_MDNS; then
  echo
  echo "===== mDNS block rule preview ====="
  echo "  $MDNS_RULE"
fi

if $DRY_RUN; then
  echo
  echo "[DRY RUN] No changes performed. Use --apply to configure Unbound and resolv.conf."
  exit 0
fi

# ---------- APPLY ----------
mkdir -p "$BACKUP_DIR"
echo "[APPLY] Backing up existing files to $BACKUP_DIR"
cp -a "$UNBOUND_CONF_DIR" "$BACKUP_DIR/unbound.conf.d.bak.$TIMESTAMP" 2>/dev/null || true
cp -a "$UNBOUND_MAIN" "$BACKUP_DIR/unbound.main.bak.$TIMESTAMP" 2>/dev/null || true
cp -a "$LOCAL_RESOLV" "$BACKUP_DIR/resolv.conf.bak.$TIMESTAMP" 2>/dev/null || true

# install unbound
echo "[APPLY] Installing unbound (if not present)"
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y unbound resolvconf ca-certificates

# ensure conf dir exists
mkdir -p "$UNBOUND_CONF_DIR"

# write the Quad9-forwarder config
echo "$UNBOUND_QUAD9" > "$UNBOUND_CONF_DIR/quad9-forward.conf"
chmod 0644 "$UNBOUND_CONF_DIR/quad9-forward.conf"
echo "[APPLY] Written $UNBOUND_CONF_DIR/quad9-forward.conf"

# initialize DNSSEC root key if needed
if [ ! -f /var/lib/unbound/root.key ]; then
  echo "[APPLY] Initializing DNSSEC trust anchor (unbound-anchor)"
  unbound-anchor -a /var/lib/unbound/root.key || echo "unbound-anchor failed - check connectivity"
fi

# point resolv.conf to local unbound
echo "$RESOLV_LOCAL" > "$LOCAL_RESOLV"
echo "[APPLY] /etc/resolv.conf now points to local Unbound"

# restart unbound
if command -v systemctl >/dev/null 2>&1; then
  systemctl restart unbound || service unbound restart || true
else
  service unbound restart || /etc/init.d/unbound restart || true
fi

# optionally block mdns
if $DISABLE_MDNS; then
  echo "[APPLY] Applying mDNS block rule"
  $MDNS_RULE || true
fi

# if user allowed RA, do nothing; if not, set per-interface blocking (careful)
if $ALLOW_RA; then
  echo "[APPLY] Leaving RA/autoconf allowed on interface $IFACE (if existent)."
else
  # block RA/autoconf on that IF (mitigation). NOTE: may remove IPv6 default route.
  echo "[APPLY] Blocking RA/autoconf on interface $IFACE (may remove SLAAC addresses/default route)"
  sysctl -w "net.ipv6.conf.$IFACE.accept_ra=0" || true
  sysctl -w "net.ipv6.conf.$IFACE.autoconf=0" || true
  # persist: create small /etc/sysctl.d entry (backed up earlier)
  SYSFILE="/etc/sysctl.d/99-skel-dhcpv6-$IFACE.conf"
  echo "net.ipv6.conf.$IFACE.accept_ra = 0" > "$SYSFILE"
  echo "net.ipv6.conf.$IFACE.autoconf = 0" >> "$SYSFILE"
  chmod 0644 "$SYSFILE"
  sysctl --system || true
fi

echo "[APPLY COMPLETE] Unbound configured and resolv.conf updated. Test with: dig @127.0.0.1 google.com AAAA"
echo "Check DNSSEC validation: delv @127.0.0.1 sigfail.example.com (expected failure) or delv @127.0.0.1 example.com (should validate)"
exit 0
