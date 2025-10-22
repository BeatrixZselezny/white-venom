#!/bin/bash
# 03_dns_quad9.sh - Unbound DNS over TLS (DoT) konfiguráció a Quad9 felé.

set -euo pipefail

UNBOUND_CONF_DIR="/etc/unbound/unbound.conf.d"
QUAD9_AAAA1="2620:fe::fe"
QUAD9_AAAA2="2620:fe::9"
RESOLV_CONF="/etc/resolv.conf"
# **JAVÍTÁS: Új fájlnév a jobb sorrend-vezérléshez**
UNBOUND_QUAD9_CONF="$UNBOUND_CONF_DIR/90-quad9-forward.conf" 
UNBOUND_MAIN_CONF="/etc/unbound/unbound.conf"

# --- LOG ÉS HIBÁK KEZELÉSE ---
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') [03_DNS] $1"
}

# **KRITIKUS: Eltároljuk az eredeti resolv.conf állapotát a rollbackhez!**
RESOLV_CONF_BACKUP="${RESOLV_CONF}.bak.03"
RESOLV_CONF_CREATED_BY_ME=0

# --- TRANZAKCIÓS TISZTÍTÁS (CLEANBACK) ---
function branch_cleanup() {
    log "[CRITICAL ALERT] Hiba történt a 03-as ág futása közben! Megkísérlem a rollbacket..."

    # 1. Unbound konfigurációs fájl feloldása/törlése
    if command -v chattr &> /dev/null; then chattr -i "$UNBOUND_QUAD9_CONF" 2>/dev/null || true; fi
    rm -f "$UNBOUND_QUAD9_CONF" || true

    # 2. **JAVÍTÁS: resolv.conf visszaállítása**
    if command -v chattr &> /dev/null; then chattr -i "$RESOLV_CONF" 2>/dev/null || true; fi

    if [ -f "$RESOLV_CONF_BACKUP" ]; then
        log "   -> $RESOLV_CONF visszaállítása a backupból."
        mv "$RESOLV_CONF_BACKUP" "$RESOLV_CONF" || true
    fi
    
    log "[CRITICAL ALERT] 03-as ág rollback befejezve. Kézi ellenőrzés szükséges!"
    exit 1
}
trap branch_cleanup ERR

log "--- 03_dns_quad9: DNS over TLS (Quad9/IPv6) konfiguráció ---"

# --- 1. UNBOUND DNS OVER TLS (DoT) KONFIGURÁCIÓ LÉTREHOZÁSA ---
log "1. Unbound DoT konfiguráció létrehozása ($UNBOUND_QUAD9_CONF)..."

read -r -d '' UNBOUND_QUAD9_CONTENT <<EOF || true
server:
    # Kernel hardeninggal szinkronban: Csak IPv6 Loopback-en figyel
    interface: ::1
    access-control: ::1/128 allow
    do-ip4: no                   # KRITIKUS: IPv4 tiltása
    do-ip6: yes
    do-udp: yes
    do-tcp: yes
    outgoing-interface: ::0
    
    # Cache / TTL hardening
    cache-min-ttl: 3600          # Min. egy óra cache, DoS/terhelés csökkentése
    cache-max-ttl: 86400         # Max. egy nap
    
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

echo "$UNBOUND_QUAD9_CONTENT" > "$UNBOUND_QUAD9_CONF"
log "Unbound forwarder fájl létrehozva: $UNBOUND_QUAD9_CONF"


# --- 2. DNSSEC ROOT KEY ELŐKÉSZÍTÉS ---
if [ ! -f /var/lib/unbound/root.key ]; then
    log "Initializing DNSSEC trust anchor (unbound-anchor)..."
    # **JAVÍTÁS: unbound-anchor hiba esetén a set -e aktiválódik!**
    unbound-anchor -a /var/lib/unbound/root.key
fi


# --- 3. KRITIKUS: RENDSZER DNS ÁTIRÁNYÍTÁSA UNBOUND-RA (::1) ---
log "3. $RESOLV_CONF átirányítása a lokális ::1 Unbound szerverre."

# 3a. Backup készítése / Állapot ellenőrzése
if [ -f "$RESOLV_CONF" ]; then
    log "   -> $RESOLV_CONF backup készítése."
    cp "$RESOLV_CONF" "$RESOLV_CONF_BACKUP"
fi

# 3b. A resolv.conf fájl lezárásának feloldása
LOCK_STATUS_RESOLV=""
if command -v chattr &> /dev/null; then
    LOCK_STATUS_RESOLV=$(lsattr "$RESOLV_CONF" 2>/dev/null | grep -o "i" || true)
    if [ "$LOCK_STATUS_RESOLV" == "i" ]; then
        log "   -> $RESOLV_CONF feloldása (chattr -i)..."
        # **JAVÍTÁS: eltávolítva a 2>/dev/null és az exit 1 hiba elnyelése!**
        chattr -i "$RESOLV_CONF" 
    fi
fi

# 3c. /etc/resolv.conf átírása a lokális ::1-re
cat > "$RESOLV_CONF" <<EOF
# resolv.conf - Generálva a 03_dns_quad9.sh hardening szkript által
# ZERO TRUST: Csak a lokális, titkosított Unbound szolgáltatás használható!
nameserver ::1
# Kiegészítő opciók a DNS szigorítására
options single-request-reopen  # Elkerüljük az IPv4 / IPv6 kettős lekérdezését
options rotate                 # Egyszerű load balancing
EOF
log "Kész: $RESOLV_CONF átírva nameserver ::1 címre."

# --- 4. SZOLGÁLTATÁSOK KEZELÉSE ÉS KONFIGURÁCIÓK ZÁRÁSA (COMMIT) ---

# 4a. resolv.conf visszazárása
if [ "$LOCK_STATUS_RESOLV" == "i" ] && command -v chattr &> /dev/null; then
    log "[COMMIT] $RESOLV_CONF visszazárása (chattr +i)..."
    chattr +i "$RESOLV_CONF" 
fi

# 4b. Unbound konfigurációs fájlok visszazárása
log "[COMMIT] Unbound konfigurációs fájlok visszazárása."
if command -v chattr &> /dev/null; then
    # **JAVÍTÁS: Eltávolítva a 2>/dev/null az összes chattr parancsról!**
    chattr +i "$UNBOUND_QUAD9_CONF"
    chattr +i "$UNBOUND_MAIN_CONF" # Fő konfiguráció is lezárva
fi

# 4c. Unbound szolgáltatás újraindítása
log "[ACTION] Unbound szolgáltatás újraindítása (Hiba esetén KILÉP!)."
if command -v service >/dev/null 2>&1; then
    # **JAVÍTÁS: Eltávolítva a || true hiba elnyelése!**
    service unbound restart || /etc/init.d/unbound restart
else
    /etc/init.d/unbound restart
fi

# Sikeres commit után töröljük a backupot
rm -f "$RESOLV_CONF_BACKUP"

log "[APPLY COMPLETE] Unbound configured for DNS over TLS (IPv6 Only). Test with: dig @::1 google.com AAAA"
exit 0
