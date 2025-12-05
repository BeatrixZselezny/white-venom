#!/usr/bin/env bash
# 03_sysctl_ip6tables-security.sh
# Sysctl + IPv6 ip6tables security configuration (IPv4-környezetre optimalizálva)

set -euo pipefail

# KONFIGURÁCIÓ
SYSCTL_CONF="/etc/sysctl.d/99-security-ipv6.conf"
SCRIPT_NAME="03_SYSCTL"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)" # Kritikus: Kötetlen változó hiba javítva

# ROLLBACK TÁRGYAK
SYSCTL_CONF_BACKUP="${SYSCTL_CONF}.bak.${SCRIPT_NAME}"
IP6TABLES_BIN="/sbin/ip6tables"
IP6TABLES_SAVE="/usr/sbin/ip6tables-save"
IP6TABLES_RESTORE="/usr/sbin/ip6tables-restore"
# Statikusan definiáljuk a detektálás helyett (Zero-Trust!)
IFACE="wlo1"

# --- LOG ÉS FUSS FUNKCIÓK ---

log() {
    local level="$1"; shift
    local msg="$*"
    printf "%s [%s/%s] %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$SCRIPT_NAME" "$level" "$msg"
}

run() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "DRY" "$*"
    else
        log "ACTION" "$*"
        "$@"
    fi
}

# --- TRANZAKCIÓS TISZTÍTÁS (BRANCH_CLEANUP) ---
function branch_cleanup() {
    log "FATAL" "Hiba történt a 03-as ág futása közben! Rollback indítása..."

    # 1. Sysctl fájl feloldása, visszaállítása és törlése (ha ez a script hozta létre)
    if command -v chattr &> /dev/null; then
        chattr -i "$SYSCTL_CONF" 2>/dev/null || true
    fi

    if [ -f "$SYSCTL_CONF_BACKUP" ]; then
        log "INFO" "-> $SYSCTL_CONF visszaállítása a backupból."
        mv "$SYSCTL_CONF_BACKUP" "$SYSCTL_CONF" || true
    else
        log "INFO" "-> $SYSCTL_CONF eltávolítása (nem volt backup)."
        rm -f "$SYSCTL_CONF" || true
    fi

    log "FATAL" "03-as ág rollback befejezve. Kézi ellenőrzés szükséges!"
    exit 1
}
trap branch_cleanup ERR

# ---------------------------------------------------------------------------
# 0. ELŐKÉSZÍTÉS ÉS BEMENET ELLENŐRZÉSE
# ---------------------------------------------------------------------------

MODE="${1:---apply}"
DRY_RUN=0
if [[ "$MODE" == "--dry-run" ]]; then
    DRY_RUN=1
    log "INFO" "Mode: --dry-run (szimuláció)"
fi

log "--- Sysctl & ip6tables hardening ($IFACE) ---"

# 1. SYSCTL KONFIGURÁCIÓ LÉTREHOZÁSA
log "1. Sysctl fájl tartalmának összeállítása ($SYSCTL_CONF)."

# KRITIKUS JAVÍTÁS: Stabilabb cat <<'EOF' használata a dry-run szintaktikai hiba elkerülése érdekében.
SYSCONF=$(cat <<'EOF'
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
kernel.unprivileged_bpf_disabled = 1 # KRITIKUS: BPF hardening

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
net.ipv6.conf.all.use_tempaddr = 2 # JAVÍTOTT: A hiányzó/hibás sort lecseréljük ALL-ra

# ICMPv6
net.ipv6.icmp.ratelimit = 100
EOF
)

# 2. IP6TABLES SZABÁLYOK LÉTREHOZÁSA
log "2. ip6tables szabályok összeállítása (IPv6 DNS szabályok eltávolítva)."

# KRITIKUS: Eltávolítottuk az IPv6 Quad9 DNS szabályokat.
build_ip6_rules() {
    cat <<EOF
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# Accept necessary ICMPv6 types for neighbor discovery, etc., rate-limited
-A INPUT -p ipv6-icmp --icmpv6-type 133 -m limit --limit 50/min -j ACCEPT
-A INPUT -p ipv6-icmp --icmpv6-type 134 -m limit --limit 50/min -j ACCEPT
-A INPUT -p ipv6-icmp --icmpv6-type 135 -m limit --limit 50/min -j ACCEPT
-A INPUT -p ipv6-icmp --icmpv6-type 136 -m limit --limit 50/min -j ACCEPT
-A INPUT -p ipv6-icmp --icmpv6-type destination-unreachable -j ACCEPT
-A INPUT -p ipv6-icmp --icmpv6-type packet-too-big -j ACCEPT
-A INPUT -p ipv6-icmp --icmpv6-type time-exceeded -j ACCEPT
-A INPUT -p ipv6-icmp --icmpv6-type parameter-problem -j ACCEPT
# KRITIKUS JAVÍTÁS: IPv6 DNS szabályok KI lettek véve

-A INPUT -m limit --limit 3/min -j LOG --log-prefix "IP6DROP: "
-A INPUT -j DROP
COMMIT
EOF
}

IP6_RULES=$(build_ip6_rules)

# ---------------------------------------------------------------------------
# 3. VÉGREHAJTÁS ÉS ZÁRÁS (COMMIT)
# ---------------------------------------------------------------------------

if $DRY_RUN; then
    # KRITIKUS JAVÍTÁS: A dry-run logolás után azonnal kilépünk a hiba elkerülése érdekében.
    log "INFO" "Sysctl contents:"
    echo "$SYSCONF" | while read -r line; do log "DRY (Sysctl): $line"; done
    log "INFO" "ip6tables rules to be applied:"
    echo "$IP6_RULES" | while read -r line; do log "DRY (ip6tables): $line"; done

    log "APPLY COMPLETE: IPv6/Sysctl hardening sikeresen alkalmazva (dry-run)."
    exit 0
fi

# Előkészítés és Backup
log "ACTION" "Kritikus fájlok backupja."
run cp "$SYSCTL_CONF" "$SYSCTL_CONF_BACKUP" 2>/dev/null || true # Eredeti backup
# Hozzáadjuk a chattr -i parancsot a lezáráshoz
LOCK_STATUS_SYSCTL=$(lsattr "$SYSCTL_CONF" 2>/dev/null | awk '{print $1}' | grep -o "i" || true)
if [ "$LOCK_STATUS_SYSCTL" == "i" ]; then
    run chattr -i "$SYSCTL_CONF"
fi

run $IP6TABLES_SAVE > "/var/backups/skell_backups/ip6tables.before.$TIMESTAMP"

# Írás és Alkalmazás
log "ACTION" "Sysctl konfiguráció írása és alkalmazása."
echo "$SYSCONF" > "$SYSCTL_CONF"
run sysctl --system

log "ACTION" "ip6tables szabályok írása és betöltése."
RULES_FILE="/etc/ip6tables/rules.v6"
run mkdir -p "$(dirname "$RULES_FILE")"
echo "$IP6_RULES" > "$RULES_FILE"

if command -v $IP6TABLES_RESTORE >/dev/null 2>&1; then
    run $IP6TABLES_RESTORE < "$RULES_FILE"
else
    log "WARN" "ip6tables-restore nem található, manuális betöltés szükséges!"
fi

# Zárás (Commit)
log "COMMIT" "Kritikus fájlok visszazárása."
# KRITIKUS: chattr hiba elnyelése nélkül!
run chattr +i "$SYSCTL_CONF"

# Rollback fájl törlése
run rm -f "$SYSCTL_CONF_BACKUP"

log "APPLY COMPLETE: IPv6/Sysctl hardening sikeresen alkalmazva."
exit 0
