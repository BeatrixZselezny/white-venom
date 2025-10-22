#!/bin/bash
# 04_dns_quad9.sh - Unbound DNS over TLS (DoT) konfiguráció a Quad9 felé.
#
# Cél: Zero Trust környezetben DNSSEC kényszerítése és a feloldás átirányítása
# a helyi, titkosított Unbound szerverre (IPv6 Only loopback ::1).
#
# KRITIKUS: Feltételezi, hogy az unbound, resolvconf és ca-certificates csomagok már telepítve vannak.

set -euo pipefail

UNBOUND_CONF_DIR="/etc/unbound/unbound.conf.d"
QUAD9_AAAA1="2620:fe::fe"
QUAD9_AAAA2="2620:fe::9"
RESOLV_CONF="/etc/resolv.conf"
UNBOUND_QUAD9_CONF="$UNBOUND_CONF_DIR/quad9-forward.conf"

# --- LOG, HELPERS és DRY_RUN KEZELÉS ---
DRY_RUN=true # Alapértelmezett: dry-run

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') [04_DNS] $1"
}

dry_run_log() {
    if $DRY_RUN; then
        log "[DRY-RUN] TENNÉ: $*"
    fi
}

usage() {
  cat <<EOF
Usage: $0 [--apply|--dry-run]
  --apply   : Apply configuration (writes config files, runs unbound-anchor, restarts service)
  --dry-run : Preview only (default)
EOF
  exit 1
}

# Argumentumok feldolgozása
if [ $# -gt 0 ]; then
  case "$1" in
    --apply) DRY_RUN=false ;;
    --dry-run) DRY_RUN=true ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
fi

branch_cleanup() {
    if $DRY_RUN; then
        log "[DRY-RUN] Hiba történt, de a dry-run miatt nincs rollback."
        exit 1
    fi
    log "[ALERT] Hiba történt a 04-es ág konfigurációs fázisa közben! Rollback..."
    # Csak a konfigurációs fájlokat távolítja el, az Unbound csomagot nem
    rm -f "$UNBOUND_QUAD9_CONF"
    log "[ALERT] 04-es ág rollback befejezve."
    # KRITIKUS: Itt a resolv.conf rollback bonyolult lenne, feltételezzük, hogy az orchestrator kezeli a teljes rollbacket
}
trap branch_cleanup ERR

log "START: Unbound DNS Hardening. Mode: $(if $DRY_RUN; then echo "DRY-RUN"; else echo "APPLY"; fi)"

# --- 1. UNBOUND DNS OVER TLS (DoT) KONFIGURÁCIÓ LÉTREHOZÁSA ---

read -r -d '' UNBOUND_QUAD9_CONTENT <<EOF || true
server:
    # Kernel hardeninggal szinkronban: Csak IPv6 Loopback-en figyel
    interface: ::1
    access-control: ::1/128 allow
    do-ip4: no
    do-ip6: yes
    do-udp: yes
    do-tcp: yes
    outgoing-interface: ::0

    # Cache / TTL hardening
    cache-min-ttl: 3600
    cache-max-ttl: 86400

    # Védelem és privacy
    hide-identity: yes
    hide-version: yes
    qname-minimisation: yes
    harden-short-buffers: yes

    # DNSSEC kényszerítése
    module-config: "validator iterator"
    auto-trust-anchor-file: "/var/lib/unbound/root.key"
    tls-cert-bundle: "/etc/ssl/certs/ca-certificates.crt"

forward-zone:
    name: "."
    # Kényszerített DNS over TLS (DoT) a 853-as porton!
    forward-addr: $QUAD9_AAAA1@853
    forward-addr: $QUAD9_AAAA2@853
    forward-ssl-upstream: yes
    forward-tls-upstream: yes

EOF

# ----------------------------------------------------
# DRY-RUN FÁZIS
# ----------------------------------------------------
if $DRY_RUN; then
    log "START: SKELL 04_dns_quad9.sh flow (DRY-RUN MODE)"

    # Konfiguráció írása
    dry_run_log "Unbound DoT konfiguráció kiírása ide: $UNBOUND_QUAD9_CONF."
    dry_run_log "A konfiguráció IPv4-et tiltja, IPv6 ::1-en figyel és Quad9-re forwardol TLS-en át."

    # DNSSEC key init
    if [ ! -f /var/lib/unbound/root.key ]; then
        dry_run_log "unbound-anchor futtatása a DNSSEC root key inicializálásához: /var/lib/unbound/root.key."
    else
        dry_run_log "DNSSEC root key már létezik."
    fi

    # resolv.conf módosítás
    LOCK_STATUS_RESOLV=$(lsattr "$RESOLV_CONF" 2>/dev/null | grep -o "i")
    if [ "$LOCK_STATUS_RESOLV" == "i" ]; then
        dry_run_log "$RESOLV_CONF fájl feloldása (chattr -i)."
    fi
    dry_run_log "resolv.conf átírása 'nameserver ::1' bejegyzéssel és 'options single-request-reopen rotate' opciókkal."
    if [ "$LOCK_STATUS_RESOLV" == "i" ]; then
        dry_run_log "$RESOLV_CONF fájl visszazárása (chattr +i)."
    fi

    # Fájlzárás és újraindítás
    dry_run_log "Unbound konfigurációs fájl ($UNBOUND_QUAD9_CONF) lezárása (chattr +i)."
    dry_run_log "Unbound szolgáltatás újraindítása (service unbound restart)."

    log "04_dns_quad9.sh completed. (DRY-RUN) RC=0"
    exit 0
fi


# ----------------------------------------------------
# APPLY FÁZIS
# ----------------------------------------------------

log "1. Unbound DoT konfiguráció létrehozása (IPv6 Only)..."
echo "$UNBOUND_QUAD9_CONTENT" > "$UNBOUND_QUAD9_CONF"
log "Unbound forwarder fájl létrehozva: $UNBOUND_QUAD9_CONF"


log "2. DNSSEC ROOT KEY ELŐKÉSZÍTÉS..."
if [ ! -f /var/lib/unbound/root.key ]; then
    log "Initializing DNSSEC trust anchor (unbound-anchor)..."
    unbound-anchor -a /var/lib/unbound/root.key || log "[ERROR] unbound-anchor failed - ellenőrizze a hálózati kapcsolatot!"
fi


log "3. KRITIKUS: RENDSZER DNS ÁTIRÁNYÍTÁSA UNBOUND-RA (::1)..."

# 3a. A resolv.conf fájl lezárásának feloldása (a 23. lépés lezárhatta)
LOCK_STATUS_RESOLV=$(lsattr "$RESOLV_CONF" 2>/dev/null | grep -o "i")
if [ "$LOCK_STATUS_RESOLV" == "i" ]; then
    log "[APPLY] $RESOLV_CONF feloldása (chattr -i)..."
    chattr -i "$RESOLV_CONF" 2>/dev/null
    if [ $? -ne 0 ]; then
        log "[KRITIKUS HIBA] $RESOLV_CONF feloldása sikertelen. Megszakítás."
        exit 1
    fi
fi

# 3b. /etc/resolv.conf átírása a lokális ::1-re
cat > "$RESOLV_CONF" <<EOF
# resolv.conf - Generálva a 04_dns_quad9.sh hardening szkript által
# ZERO TRUST: Csak a lokális, titkosított Unbound szolgáltatás használható!
nameserver ::1
# Kiegészítő opciók a DNS szigorítására
options single-request-reopen
options rotate
EOF
log "Kész: $RESOLV_CONF átírva nameserver ::1 címre."

# 3c. Visszazárás, ha eredetileg le volt zárva
if [ "$LOCK_STATUS_RESOLV" == "i" ]; then
    log "[APPLY] $RESOLV_CONF visszazárása (chattr +i)..."
    chattr +i "$RESOLV_CONF" 2>/dev/null
fi


log "4. SZOLGÁLTATÁSOK KEZELÉSE ÉS KONFIGURÁCIÓK ZÁRÁSA..."

# Unbound konfigurációs fájlok visszazárása
log "Konfigurációs fájlok visszazárása..."
chattr +i "$UNBOUND_QUAD9_CONF" 2>/dev/null
# chattr +i /etc/unbound/unbound.conf # A fő fájl zárása opcionális

# Unbound szolgáltatás újraindítása
log "Unbound szolgáltatás újraindítása..."
if command -v service >/dev/null 2>&1; then
    service unbound restart || /etc/init.d/unbound restart || true
else
    /etc/init.d/unbound restart || true
fi

log "[APPLY COMPLETE] Unbound configured for DNS over TLS (IPv6 Only). Test with: dig @::1 google.com AAAA"
exit 0
