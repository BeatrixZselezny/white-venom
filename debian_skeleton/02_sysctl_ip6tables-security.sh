#!/bin/bash
# branches/02-sysctl-ip6tables-security.sh
# IPv6 baseline sysctl + ip6tables hardening + WireGuard PostUp/PostDown integration
# Author: Beatrix Zelezny 🐱  (with GPT-5 integration)
set -euo pipefail

SYSCTL_CONF="/etc/sysctl.d/99-security-ipv6.conf"
BACKUP_DIR="${BRANCH_BACKUP_DIR:-/tmp/branch_backup_02}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
IP6TABLES_BIN="/sbin/ip6tables"
IP6TABLES_SAVE="/sbin/ip6tables-save"
WG_PORT=51820
DRY_RUN=true
ALLOW_WG=false
IFACE=""

usage() {
  cat <<EOF
Usage: $0 [--iface IFACE] [--apply|--dry-run] [--allow-wg]
  --iface IFACE   : Target interface (default: autodetect)
  --apply         : Apply configuration (writes sysctl + applies rules)
  --dry-run       : Preview only (default)
  --allow-wg      : Enable WireGuard UDP port $WG_PORT rules + PostUp/PostDown scripts
EOF
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --iface) IFACE="$2"; shift 2;;
    --apply) DRY_RUN=false; shift;;
    --dry-run) DRY_RUN=true; shift;;
    --allow-wg) ALLOW_WG=true; shift;;
    -h|--help) usage;;
    *) echo "Unknown arg: $1"; usage;;
  esac
done

[ "$(id -u)" -eq 0 ] || { echo "Run as root"; exit 2; }

# autodetect IPv6 interface
if [ -z "$IFACE" ]; then
  IFACE=$(ip -6 route show default 2>/dev/null | awk '/default/ {for(i=1;i<=NF;i++) if ($i=="dev"){print $(i+1); exit}}')
  [ -z "$IFACE" ] && IFACE=$(ip -6 addr show scope global | awk '/inet6/ {iface=$2} /^[0-9]+:/ {gsub(":","",$2)} END{print iface}')
fi

if [ -z "$IFACE" ]; then
  echo "Could not autodetect IPv6 interface. Use --iface manually."
  exit 3
fi

echo "Target interface: $IFACE"
echo "Mode: $( $DRY_RUN && echo DRY-RUN || echo APPLY )"
echo "WireGuard: $( $ALLOW_WG && echo ENABLED || echo DISABLED )"

# --- SYSCTL BASELINE (trimmed & optimized for IPv6 + hardening) ---
read -r -d '' SYSCONF <<EOF || true
# Core kernel and filesystem protections
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 1
kernel.panic = 30
kernel.panic_on_oops = 1
kernel.modules_disabled = 1
kernel.unprivileged_bpf_disabled = 1
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_regular = 2
fs.protected_fifos = 2
fs.suid_dumpable = 0

# Virtual memory & performance tweaks
vm.mmap_min_addr = 65536
vm.swappiness = 10

# IPv6 Security baseline
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
net.ipv6.conf.all.forwarding = 0
net.ipv6.conf.default.forwarding = 0

# Privacy addresses (RFC 4941)
net.ipv6.conf.all.use_tempaddr = 2
net.ipv6.conf.default.use_tempaddr = 2
net.ipv6.conf.$IFACE.use_tempaddr = 2

# Optional (commented to avoid breaking hotspot RA):
# net.ipv6.conf.all.accept_ra = 0
# net.ipv6.conf.$IFACE.accept_ra = 0

# ICMPv6 rate limit
net.ipv6.icmp.ratelimit = 100
EOF

# --- ip6tables baseline ruleset ---
build_ip6_rules() {
  cat <<'RULES'
__IP6__ -F
__IP6__ -X
__IP6__ -P INPUT DROP
__IP6__ -P FORWARD DROP
__IP6__ -P OUTPUT ACCEPT

# Loopback
__IP6__ -A INPUT -i lo -j ACCEPT

# Established
__IP6__ -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow ICMPv6 ND types
for t in 133 134 135 136; do
  __IP6__ -A INPUT -p ipv6-icmp --icmpv6-type $t -m limit --limit 50/min -j ACCEPT
done

# Allow essential ICMPv6
__IP6__ -A INPUT -p ipv6-icmp --icmpv6-type destination-unreachable -j ACCEPT
__IP6__ -A INPUT -p ipv6-icmp --icmpv6-type packet-too-big -j ACCEPT
__IP6__ -A INPUT -p ipv6-icmp --icmpv6-type time-exceeded -j ACCEPT
__IP6__ -A INPUT -p ipv6-icmp --icmpv6-type parameter-problem -j ACCEPT

# Allow Quad9 DNS out
__IP6__ -A OUTPUT -o __IFACE__ -p udp -d 2620:fe::fe --dport 53 -j ACCEPT
__IP6__ -A OUTPUT -o __IFACE__ -p udp -d 2620:fe::9 --dport 53 -j ACCEPT
__IP6__ -A OUTPUT -o __IFACE__ -p tcp -d 2620:fe::fe --dport 53 -j ACCEPT
__IP6__ -A OUTPUT -o __IFACE__ -p tcp -d 2620:fe::9 --dport 53 -j ACCEPT

# WireGuard
if [ "__ALLOW_WG__" = "true" ]; then
  __IP6__ -A INPUT -i __IFACE__ -p udp --dport __WGPORT__ -j ACCEPT
  __IP6__ -A OUTPUT -o __IFACE__ -p udp --sport __WGPORT__ -j ACCEPT
fi

# Drop & log unknowns
__IP6__ -A INPUT -m limit --limit 3/min -j LOG --log-prefix "IP6DROP: "
__IP6__ -A INPUT -j DROP
RULES
}

IP6_RAW=$(build_ip6_rules)
IP6_RENDERED=$(echo "$IP6_RAW" | sed "s|__IP6__|$IP6TABLES_BIN|g" \
                                 | sed "s|__IFACE__|$IFACE|g" \
                                 | sed "s|__WGPORT__|$WG_PORT|g")
if $ALLOW_WG; then
  IP6_RENDERED=$(echo "$IP6_RENDERED" | sed "s/__ALLOW_WG__/true/g")
else
  IP6_RENDERED=$(echo "$IP6_RENDERED" | sed "s/__ALLOW_WG__/false/g")
fi

# --- WG PostUp/PostDown integration ---
WG_POSTUP="/etc/wireguard/postup_ipv6.sh"
WG_POSTDOWN="/etc/wireguard/postdown_ipv6.sh"

WG_POSTUP_CONTENT="#!/bin/bash
# WireGuard PostUp IPv6 hardening
$IP6TABLES_BIN -A INPUT -i $IFACE -p udp --dport $WG_PORT -j ACCEPT
$IP6TABLES_BIN -A OUTPUT -o $IFACE -p udp --sport $WG_PORT -j ACCEPT
"

WG_POSTDOWN_CONTENT="#!/bin/bash
# WireGuard PostDown IPv6 cleanup
$IP6TABLES_BIN -D INPUT -i $IFACE -p udp --dport $WG_PORT -j ACCEPT 2>/dev/null || true
$IP6TABLES_BIN -D OUTPUT -o $IFACE -p udp --sport $WG_PORT -j ACCEPT 2>/dev/null || true
"

echo "===== SYSCTL PREVIEW ====="
echo "$SYSCONF"
echo "===== ip6tables PREVIEW ====="
echo "$IP6_RENDERED"

if $DRY_RUN; then
  echo "[DRY RUN] No changes made. Use --apply to enforce."
  exit 0
fi

echo "[APPLY] Creating backups at $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp -a "$SYSCTL_CONF" "$BACKUP_DIR/99-security-ipv6.conf.bak" 2>/dev/null || true
$IP6TABLES_SAVE > "$BACKUP_DIR/ip6tables.before.$TIMESTAMP" 2>/dev/null || true

echo "$SYSCONF" > "$SYSCTL_CONF"
sysctl --system || true

TMP_RULES="/tmp/ip6apply_${TIMESTAMP}.sh"
echo "#!/bin/bash" > "$TMP_RULES"
echo "$IP6_RENDERED" >> "$TMP_RULES"
chmod 700 "$TMP_RULES"
bash "$TMP_RULES"

if $ALLOW_WG; then
  echo "$WG_POSTUP_CONTENT" > "$WG_POSTUP"
  echo "$WG_POSTDOWN_CONTENT" > "$WG_POSTDOWN"
  chmod 700 "$WG_POSTUP" "$WG_POSTDOWN"
  echo "[APPLY] WG PostUp/PostDown scripts created in /etc/wireguard/"
fi

echo "[APPLY COMPLETE] IPv6 + WireGuard baseline ready. Verify with:"
echo "  sysctl -a | grep ipv6.conf"
echo "  ip6tables -L -v"
