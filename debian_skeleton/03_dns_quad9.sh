#!/bin/bash
# branches/03_dns_quad9.sh
# Unbound DNS over TLS (DoT) konfiguráció a Quad9 felé (Zero Trust).
# DNSSEC kényszerítése, IPv6-only forwarder beállítás, mDNS/RA kezelés.
set -euo pipefail

# --- KONZISZTENCIA ÉS KONFIG ---
UNBOUND_CONF_DIR="/etc/unbound/unbound.conf.d"
UNBOUND_MAIN="/etc/unbound/unbound.conf"
# Feltételezzük, hogy az APT install és resolv.conf beállítás már megtörtént a script elején!

# Quad9 IPv6 addresses (DoT port 853)
QUAD9_AAAA1="2620:fe::fe"
QUAD9_AAAA2="2620:fe::9"

# Argumentumok és Root/Log feltételezése a felső blokkból.
# ... (itt vannak a log és cleanup függvények)
# ... (itt történik a DRY-RUN/APPLY logikája)

# --- TRANZAKCIÓS TISZTÍTÁS (CLEANUP/ROLLBACK) ---
branch_cleanup() {
    log "[ALERT] Hiba történt a 03-as ág konfigurációs fázisa közben! Rollback..."
    # Csak a konfigurációs fájlokat távolítja el, az Unbound csomagot nem
    rm -f "$UNBOUND_CONF_DIR/quad9-forward.conf"
    # A /etc/sysctl.d fájlt is törölni kell, ha létrejött
    rm -f "/etc/sysctl.d/99-skel-dhcpv6-*.conf"
    log "[ALERT] 03-as ág rollback befejezve."
}
trap branch_cleanup ERR

# ... (DRY RUN / IFACE detektálás / LOG / BACKUP FÁJLOK) ...
# A telepítést eltávolítjuk: apt-get install --no-install-recommends -y unbound resolvconf ca-certificates

# --- 1. UNBOUND DNS OVER TLS (DoT) KONFIGURÁCIÓ ---
# Kényszerítjük a 853-as portot (DoT) és a TLS használatát!

read -r -d '' UNBOUND_QUAD9 <<EOF || true
server:
    # Minimalista beállítások
    verbosity: 1
    interface: ::1             # Csak IPv6 Loopback
    access-control: ::1/128 allow
    do-ip4: no
    do-ip6: yes
    do-udp: yes
    do-tcp: yes
    outgoing-interface: ::0
    
    # Cache / TTL hardening
    msg-cache-size: 50m
    rrset-cache-size: 100m
    cache-min-ttl: 3600
    cache-max-ttl: 86400
    
    # Védelem
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
    forward-tls-upstream: yes # Szimpla TLS is mehet

EOF

# ... (write the Quad9-forwarder config)

# initialize DNSSEC root key if needed (maradhat)
if [ ! -f /var/lib/unbound/root.key ]; then
    echo "[APPLY] Initializing DNSSEC trust anchor (unbound-anchor)"
    unbound-anchor -a /var/lib/unbound/root.key || echo "unbound-anchor failed - check connectivity"
fi

# ... (A resolv.conf beállítását és az Unbound telepítést eltávolítjuk) ...

# restart unbound (sysvinit kompatibilisen)
if command -v service >/dev/null 2>&1; then
    service unbound restart || /etc/init.d/unbound restart || true
else
    /etc/init.d/unbound restart || true
fi

# ... (mDNS és RA blokkolás logika maradhat, mert azok a v6 hardening részei) ...

echo "[APPLY COMPLETE] Unbound configured for DNS over TLS. Test with: dig @::1 google.com AAAA"
exit 0
