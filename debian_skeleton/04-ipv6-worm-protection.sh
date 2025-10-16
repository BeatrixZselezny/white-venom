#!/bin/bash
# branches/04-ipv6-worm-protection.sh
# IPv6 "v6worms" protection (sysctl + ip6tables)
# Implements mitigations inspired by Bellovin/Cheswick/Keromytis (v6 worm strategies)
# Usage:
#   sudo ./04-ipv6-worm-protection.sh --dry-run [--iface IFACE] [--allow-ra] [--allow-wg]
#   sudo ./04-ipv6-worm-protection.sh --apply  [--iface IFACE] [--allow-ra] [--allow-wg]
#
# Behaviour:
#  - dry-run: shows the sysctl content and ip6tables preview but does not apply
#  - apply: backups current sysctl + ip6tables, writes files, applies sysctls and rules
#
set -euo pipefail

# ---------- CONFIG ----------
SYSCTL_CONF="/etc/sysctl.d/99-ipv6-worms.conf"
IP6TABLES_BIN="/sbin/ip6tables"
IP6TABLES_SAVE="/sbin/ip6tables-save"
BACKUP_DIR="${BRANCH_BACKUP_DIR:-/tmp/branch_backup_04}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
DRY_RUN=true
WG_PORT=51820

usage() {
  cat <<EOF
Usage: $0 [--iface IFACE] [--apply|--dry-run] [--allow-ra] [--allow-wg]
  --iface IFACE : target interface for per-interface sysctl rules (autodetected if omitted)
  --dry-run     : show planned changes (default)
  --apply       : make changes (writes sysctl + runs ip6tables)
  --allow-ra    : allow accepting Router Advertisements on the IF (default: blocked)
  --allow-wg    : allow WireGuard UDP port (${WG_PORT}) on IF (adds rule)
EOF
  exit 1
}

IFACE=""
ALLOW_RA=false
ALLOW_WG=false

# parse args
while [ $# -gt 0 ]; do
  case "$1" in
    --iface) IFACE="$2"; shift 2;;
    --apply) DRY_RUN=false; shift;;
    --dry-run) DRY_RUN=true; shift;;
    --allow-ra) ALLOW_RA=true; shift;;
    --allow-wg) ALLOW_WG=true; shift;;
    -h|--help) usage;;
    *) echo "Unknown arg: $1"; usage;;
  esac
done

# root check
[ "$(id -u)" -eq 0 ] || { echo "Run as root"; exit 2; }

# autodetect interface that has global IPv6 address or default route
if [ -z "$IFACE" ]; then
  IFACE=$(ip -6 route show default 2>/dev/null | awk '/default/ {for(i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}' || true)
  if [ -z "$IFACE" ]; then
    IFACE=$(ip -6 addr show scope global | awk '/^[0-9]+:/{iface=$2} /inet6/ && /scope global/ {gsub(/:$/,"",iface); print iface; exit}')
  fi
fi

if [ -z "$IFACE" ]; then
  echo "ERROR: could not autodetect IPv6 interface. Pass --iface IFACE" >&2
  exit 3
fi

echo "Target interface for IPv6-worm protection: $IFACE"
echo "ALLOW_RA = $ALLOW_RA ; ALLOW_WG = $ALLOW_WG"
echo "Mode: $( $DRY_RUN && echo DRY-RUN || echo APPLY )"

# ---------- Build sysctl content ----------
# We will keep global hardening, but make RA/autoconf per-interface:
read -r -d '' SYSCONF <<'EOF' || true
# IPv6 worm protection sysctl (generated)
# Global kernel hardening (non-interface-specific)
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
net.ipv6.conf.all.forwarding = 0
net.ipv6.conf.default.forwarding = 0
# limit ICMPv6 (kernel-level ratelimiting where available)
net.ipv6.icmp.ratelimit = 100
# protect ND tables a bit (not perfect but helpful)
net.ipv6.neigh.default.gc_thresh1 = 128
net.ipv6.neigh.default.gc_thresh2 = 512
net.ipv6.neigh.default.gc_thresh3 = 1024
# filesystem / kernel protections (useful generally)
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 1
EOF

# Add per-interface choices for RA/autoconf depending on --allow-ra
if $ALLOW_RA; then
  # allow RA/autoconf on the chosen interface (useful if hotspot provides RA)
  SYSCONF="$SYSCONF"$'\n'"# Allow RA on $IFACE (explicit because --allow-ra passed)"
  SYSCONF="$SYSCONF"$'\n'"net.ipv6.conf.$IFACE.accept_ra = 1"
  SYSCONF="$SYSCONF"$'\n'"net.ipv6.conf.$IFACE.autoconf = 1"
  SYSCONF="$SYSCONF"$'\n'"net.ipv6.conf.$IFACE.accept_ra_defrtr = 1"
else
  # block RA/autoconf on the chosen interface (safer default)
  SYSCONF="$SYSCONF"$'\n'"# Block Router Advertisements and autoconf on $IFACE by default (mitigation)"
  SYSCONF="$SYSCONF"$'\n'"net.ipv6.conf.$IFACE.accept_ra = 0"
  SYSCONF="$SYSCONF"$'\n'"net.ipv6.conf.$IFACE.autoconf = 0"
  SYSCONF="$SYSCONF"$'\n'"net.ipv6.conf.$IFACE.accept_ra_defrtr = 0"
fi

# Additional per-interface privacy/enforcement
SYSCONF="$SYSCONF"$'\n'"# Prefer temporary (privacy) addresses on IF"
SYSCONF="$SYSCONF"$'\n'"net.ipv6.conf.$IFACE.use_tempaddr = 2"

# ---------- Build ip6tables rule set ----------
# Strategy:
#  - allow loopback, established
#  - allow essential ICMPv6 types (133-136) for ND, but rate-limit them
#  - block other multicast destinations (ff00::/8) unless ICMPv6 ND types
#  - drop suspicious packets and log limited
#  - optionally allow WG port
build_ip6_rules() {
  cat <<'RULES'
# Flush tables
__IP6__ -F
__IP6__ -X

# Default policies
__IP6__ -P INPUT DROP
__IP6__ -P FORWARD DROP
__IP6__ -P OUTPUT ACCEPT

# Allow loopback
__IP6__ -A INPUT -i lo -j ACCEPT

# Allow established/related
__IP6__ -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow Neighbor Discovery ICMPv6 types (rate-limited)
# 133 Router Solicitation, 134 Router Advertisement,
# 135 Neighbor Solicitation, 136 Neighbor Advertisement
__IP6__ -A INPUT -p ipv6-icmp --icmpv6-type 133 -m limit --limit 30/min -j ACCEPT
__IP6__ -A INPUT -p ipv6-icmp --icmpv6-type 134 -m limit --limit 30/min -j ACCEPT
__IP6__ -A INPUT -p ipv6-icmp --icmpv6-type 135 -m limit --limit 100/min -j ACCEPT
__IP6__ -A INPUT -p ipv6-icmp --icmpv6-type 136 -m limit --limit 100/min -j ACCEPT

# Allow some other essential ICMPv6 types (fragmentation, unreachable, time-exceeded)
__IP6__ -A INPUT -p ipv6-icmp --icmpv6-type destination-unreachable -j ACCEPT
__IP6__ -A INPUT -p ipv6-icmp --icmpv6-type packet-too-big -j ACCEPT
__IP6__ -A INPUT -p ipv6-icmp --icmpv6-type time-exceeded -j ACCEPT
__IP6__ -A INPUT -p ipv6-icmp --icmpv6-type parameter-problem -j ACCEPT

# Block non-ND multicast traffic arriving to the interface (drop other ff00::/8)
# We'll DROP packets whose destination is multicast but are not ND ICMPv6 types
# (we implemented ND types accept above; now drop multicast that reaches INPUT)
__IP6__ -A INPUT -d ff00::/8 -i __IFACE__ -j DROP

# Allow DNS to Quad9 via the interface (if you want; adjust or remove)
__IP6__ -A OUTPUT -o __IFACE__ -p udp -d __Q1__ --dport 53 -j ACCEPT
__IP6__ -A OUTPUT -o __IFACE__ -p tcp -d __Q1__ --dport 53 -j ACCEPT
__IP6__ -A OUTPUT -o __IFACE__ -p udp -d __Q2__ --dport 53 -j ACCEPT
__IP6__ -A OUTPUT -o __IFACE__ -p tcp -d __Q2__ --dport 53 -j ACCEPT

# Optional: allow WireGuard UDP port
if [ "__ALLOW_WG__" = "true" ]; then
  __IP6__ -A INPUT -i __IFACE__ -p udp --dport __WGPORT__ -m conntrack --ctstate NEW -j ACCEPT
fi

# Log a small amount and drop the rest
__IP6__ -A INPUT -m limit --limit 5/min -j LOG --log-prefix "V6WORMDROP: "
__IP6__ -A INPUT -j DROP
RULES
}

IP6_RAW=$(build_ip6_rules)
IP6_RENDERED=$(printf "%s" "$IP6_RAW" | sed "s|__IP6__|$IP6TABLES_BIN|g" \
                                          | sed "s|__IFACE__|$IFACE|g" \
                                          | sed "s|__Q1__|2620:fe::fe|g" \
                                          | sed "s|__Q2__|2620:fe::9|g" \
                                          | sed "s|__WGPORT__|$WG_PORT|g")

if $ALLOW_WG; then
  IP6_RENDERED=$(printf "%s" "$IP6_RENDERED" | sed "s/__ALLOW_WG__/true/g")
else
  IP6_RENDERED=$(printf "%s" "$IP6_RENDERED" | sed "s/__ALLOW_WG__/false/g")
fi

# ---------- Show preview ----------
echo "===== SYSCTL (will be written to: $SYSCTL_CONF) ====="
echo "$SYSCONF" | sed 's/^/  /'
echo
echo "===== ip6tables preview (will be executed) ====="
echo "$IP6_RENDERED" | sed 's/^/  /'

if $DRY_RUN; then
  echo
  echo "[DRY RUN] No changes applied. Re-run with --apply to enforce protections."
  exit 0
fi

# ---------- APPLY FLOW ----------
echo "[APPLY] Creating backup dir: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp -a "$SYSCTL_CONF" "$BACKUP_DIR/99-ipv6-worms.conf.bak" 2>/dev/null || true
$IP6TABLES_SAVE > "$BACKUP_DIR/ip6tables.before.$TIMESTAMP" 2>/dev/null || true

# Write sysctl file
echo "$SYSCONF" > "$SYSCTL_CONF"
chmod 0644 "$SYSCTL_CONF"

# Apply sysctl changes
echo "[APPLY] Running sysctl --system (may take effect immediately)"
sysctl --system || echo "sysctl --system returned non-zero, check manually"

# Create temporary ip6tables script and execute
TMP_SCRIPT="/tmp/v6worm_ip6_apply_$TIMESTAMP.sh"
cat > "$TMP_SCRIPT" <<'SH'
#!/bin/bash
set -euo pipefail
# this script executes the rendered ip6tables commands
SH
printf "%s\n" "$IP6_RENDERED" >> "$TMP_SCRIPT"
chmod 0700 "$TMP_SCRIPT"

echo "[APPLY] Executing ip6tables script: $TMP_SCRIPT"
bash "$TMP_SCRIPT"

# Persist rules if possible
if command -v netfilter-persistent >/dev/null 2>&1; then
  netfilter-persistent save || true
elif [ -x /sbin/ip6tables-save ] || [ -x /usr/sbin/ip6tables-save ]; then
  $IP6TABLES_SAVE > /etc/ip6tables.rules.$TIMESTAMP || true
  echo "Saved ip6tables snapshot to /etc/ip6tables.rules.$TIMESTAMP"
fi

echo "[APPLY] IPv6 worm protections applied. Backups in: $BACKUP_DIR"
echo "Check active rules: $IP6TABLES_BIN -L -v --line-numbers"
exit 0
