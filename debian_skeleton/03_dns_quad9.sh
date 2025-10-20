#!/bin/bash
# 03_dns_quad9.sh - Unbound DNS over TLS (DoT) konfiguráció a Quad9 felé.
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

# --- LOG ÉS HIBÁK KEZELÉSE ---
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') [03_DNS] $1"
}

branch_cleanup() {
    log "[ALERT] Hiba történt a 03-as ág konfigurációs fázisa közben! Rollback..."
    # Csak a konfigurációs fájlokat távolítja el, az Unbound csomagot nem
    rm -f "$UNBOUND_QUAD9_CONF"
    log "[ALERT] 03-as ág rollback befejezve."
    # KRITIKUS: Ne felejtsük el, hogy a főszerkesztési folyamatban szükség lehet resolv.conf rollbackre is!
}
trap branch_cleanup ERR

# --- 1. UNBOUND DNS OVER TLS (DoT) KONFIGURÁCIÓ LÉTREHOZÁSA ---
log "1. Unbound DoT konfiguráció létrehozása (IPv6 Only)..."

read -r -d '' UNBOUND_QUAD9_CONTENT <<EOF || true
server:
    # Kernel hardeninggal szinkronban: Csak IPv6 Loopback-en figyel
    interface: ::1
    access-control: ::1/128 allow
    do-ip4: no                   # KRITIKUS: IPv4 tiltása
    do-ip6: yes
    do-udp: yes
    do-tcp: yes
    outgoing-interface: ::0
    
    # Cache / TTL hardening
    cache-min-ttl: 3600          # Min. egy óra cache, DoS/terhelés csökkentése
    cache-max-ttl: 86400         # Max. egy nap
    
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
    unbound-anchor -a /var/lib/unbound/root.key || log "[ERROR] unbound-anchor failed - ellenőrizze a hálózati kapcsolatot!"
fi


# --- 3. KRITIKUS: RENDSZER DNS ÁTIRÁNYÍTÁSA UNBOUND-RA (::1) ---

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
# resolv.conf - Generálva a 03_dns_quad9.sh hardening szkript által
# ZERO TRUST: Csak a lokális, titkosított Unbound szolgáltatás használható!
nameserver ::1
# Kiegészítő opciók a DNS szigorítására
options single-request-reopen  # Elkerüljük az IPv4 / IPv6 kettős lekérdezését
options rotate                 # Egyszerű load balancing
EOF
log "Kész: $RESOLV_CONF átírva nameserver ::1 címre."

# 3c. Visszazárás, ha eredetileg le volt zárva
if [ "$LOCK_STATUS_RESOLV" == "i" ]; then
    log "[APPLY] $RESOLV_CONF visszazárása (chattr +i)..."
    chattr +i "$RESOLV_CONF" 2>/dev/null
fi


# --- 4. SZOLGÁLTATÁSOK KEZELÉSE ÉS KONFIGURÁCIÓK ZÁRÁSA ---

# Unbound konfigurációs fájlok visszazárása
log "Konfigurációs fájlok visszazárása..."
chattr +i "$UNBOUND_QUAD9_CONF" 2>/dev/null
# chattr +i /etc/unbound/unbound.conf # A fő fájlt is vissza kell zárni!

# Unbound szolgáltatás újraindítása
log "Unbound szolgáltatás újraindítása..."
if command -v service >/dev/null 2>&1; then
    service unbound restart || /etc/init.d/unbound restart || true
else
    /etc/init.d/unbound restart || true
fi

# Mivel az mDNS és RA blokkolás a 27. lépésben megtörtént, azt itt nem ismételjük.

log "[APPLY COMPLETE] Unbound configured for DNS over TLS (IPv6 Only). Test with: dig @::1 google.com AAAA"
exit 0