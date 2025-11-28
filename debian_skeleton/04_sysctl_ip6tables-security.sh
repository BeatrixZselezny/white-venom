#!/bin/bash
# 04_sysctl_ip6tables-security.sh
# Sysctl + IPv6 ip6tables security configuration
# Author: Beatrix Zselezny 🐱

set -euo pipefail

SYSCTL_CONF="/etc/sysctl.d/99-security-ipv6.conf"
BACKUP_DIR="${BRANCH_BACKUP_DIR:-/var/backups/skell_backups/03_sysctl}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
IP6TABLES_BIN="/sbin/ip6tables"
IP6TABLES_SAVE="/usr/sbin/ip6tables-save"
IP6TABLES_RESTORE="/usr/sbin/ip6tables-restore"
DRY_RUN=true
IFACE=""

usage() {
  cat <<EOF
Usage: $0 [--iface IFACE] [--apply|--dry-run]
  --iface IFACE : Target interface (default: autodetect)
  --apply   : Apply configuration
  --dry-run : Preview only (default)
EOF
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --iface) IFACE="$2"; shift 2;;
    --apply) DRY_RUN=false; shift;;
    --dry-run) DRY_RUN=true; shift;;
    -h|--help) usage;;
    *) echo "Unknown arg: $1"; usage;;
  esac
done

log() { echo "$(date +%F' '%T) [SYSCTL] $*"; }
dry_run_log() { $DRY_RUN && log "[DRY-RUN] $*"; }

read -r -d '' SYSCONF <<EOF || true
# Kernel and filesystem protections
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 1
kernel.panic = 30
kernel.panic_on_oops = 1
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_regular = 2
fs.protected_fifos = 2
fs.suid_dumpable = 0

# Memory performance
vm.mmap_min_addr = 65536
vm.swappiness = 10

# IPv6 security
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
net.ipv6.conf.all.forwarding = 0
net.ipv6.conf.default.forwarding = 0

# Privacy (RFC 4941)
net.ipv6.conf.all.use_tempaddr = 2
net.ipv6.conf.default.use_tempaddr = 2
net.ipv6.conf.${IFACE}.use_tempaddr = 2

# ICMPv6
net.ipv6.icmp.ratelimit = 100
EOF

build_ip6_rules() {
  cat <<EOF
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A INPUT -p ipv6-icmp --icmpv6-type 133 -m limit --limit 50/min -j ACCEPT
-A INPUT -p ipv6-icmp --icmpv6-type 134 -m limit --limit 50/min -j ACCEPT
-A INPUT -p ipv6-icmp --icmpv6-type 135 -m limit --limit 50/min -j ACCEPT
-A INPUT -p ipv6-icmp --icmpv6-type 136 -m limit --limit 50/min -j ACCEPT
-A INPUT -p ipv6-icmp --icmpv6-type destination-unreachable -j ACCEPT
-A INPUT -p ipv6-icmp --icmpv6-type packet-too-big -j ACCEPT
-A INPUT -p ipv6-icmp --icmpv6-type time-exceeded -j ACCEPT
-A INPUT -p ipv6-icmp --icmpv6-type parameter-problem -j ACCEPT
-A OUTPUT -o ${IFACE} -p udp -d 2620:fe::fe --dport 53 -j ACCEPT
-A OUTPUT -o ${IFACE} -p udp -d 2620:fe::9 --dport 53 -j ACCEPT
-A OUTPUT -o ${IFACE} -p tcp -d 2620:fe::fe --dport 53 -j ACCEPT
-A OUTPUT -o ${IFACE} -p tcp -d 2620:fe::9 --dport 53 -j ACCEPT
-A INPUT -m limit --limit 3/min -j LOG --log-prefix "IP6DROP: "
-A INPUT -j DROP
COMMIT
EOF
}

IP6_RULES=$(build_ip6_rules)

if $DRY_RUN; then
  log "Running in dry-run mode."
  dry_run_log "Sysctl would be written to $SYSCTL_CONF."
  dry_run_log "Sysctl contents:"
  echo "$SYSCONF" | while read -r line; do dry_run_log "$line"; done
  dry_run_log "ip6tables rules to be applied:"
  echo "$IP6_RULES" | while read -r line; do dry_run_log "$line"; done
  exit 0
fi

log "Creating backup at $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp -a "$SYSCTL_CONF" "$BACKUP_DIR/99-security-ipv6.conf.bak" 2>/dev/null || true
$IP6TABLES_SAVE > "$BACKUP_DIR/ip6tables.before.$TIMESTAMP" 2>/dev/null || true

log "Writing sysctl config to $SYSCTL_CONF"
echo "$SYSCONF" > "$SYSCTL_CONF"

log "Applying sysctl settings"
sysctl --system || true

log "Applying ip6tables rules"
RULES_FILE="/etc/ip6tables/rules.v6"
mkdir -p "$(dirname "$RULES_FILE")"
echo "$IP6_RULES" > "$RULES_FILE"

if command -v $IP6TABLES_RESTORE >/dev/null 2>&1; then
  $IP6TABLES_RESTORE < "$RULES_FILE" || log "[WARN] ip6tables-restore failed"
  log "ip6tables rules loaded from $RULES_FILE"
else
  log "[WARN] ip6tables-restore not found"
fi

log "IPv6 hardening complete"
exit 0
