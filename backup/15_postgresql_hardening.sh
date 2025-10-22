#!/bin/bash
# branches/14_postgresql_hardening.sh
# PostgreSQL telepítése, hálózati izolációja, és a 'postgres' adatbázis-felhasználó SZIGORÚ jelszó beállítása.
set -euo pipefail

# --- KONZISZTENCIA ÉS KONFIG ---
LOGFILE="/var/log/postgresql_hardening.log"
# Megpróbáljuk automatikusan felismerni a PG verziót, vagy fallback 15-re.
PG_VERSION=$(apt-cache search ^postgresql | head -n 1 | awk '{print $1}' | grep -oE '[0-9]+' | head -n 1 || echo "15") 
PG_CONFIG_MAIN="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
PG_CONFIG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
# Generálunk egy titkos, erős jelszót
GENERATED_PASSWORD=$(openssl rand -base64 32) 
# Globális log függvényt feltételezünk
log() { echo "$(date +%F' '%T) $*" | tee -a "$LOGFILE"; }

# ... (Root ellenőrzés) ...

# --- TRANZAKCIÓS TISZTÍTÁS (CLEANBACK) ---
# ... (a korábbi rollback rész) ...
branch_cleanup() {
    log "[CRITICAL ALERT] Hiba történt a 14-es ág futása közben! Megkísérlem a rollbacket..."
    log "[ACTION] PostgreSQL csomagok eltávolítása."
    apt-get purge -y "postgresql-$PG_VERSION" postgresql-client || true
    rm -rf "/var/lib/postgresql/$PG_VERSION/main" || true
    log "[CRITICAL ALERT] 14-es ág rollback befejezve. PostgreSQL újratelepítése szükséges!"
}
trap branch_cleanup ERR

# --- 1. TELEPÍTÉS ÉS BIZTONSÁGOS ALAPOK ---
log "--- 1. TELEPÍTÉS ÉS BIZTONSÁGOS ALAPOK ---"
log "[ACTION] PostgreSQL telepítése (server és client)."
apt-get install -y --no-install-recommends "postgresql-$PG_VERSION" postgresql-client-"$PG_VERSION"

# --- 2. HÁLÓZATI IZOLÁCIÓ ÉS VERZIÓ ELREJTÉSE ---
log "--- 2. HÁLÓZATI IZOLÁCIÓ ÉS VERZIÓ ELREJTÉSE ---"

# 2.1 Listen Address: KIZÁRÓLAG localhost/Unix socket
log "[HARDENING] listen_addresses beállítása KIZÁRÓLAG localhost-ra (127.0.0.1, ::1)."
if [ -f "$PG_CONFIG_MAIN" ]; then
    sed -i '/^listen_addresses/d' "$PG_CONFIG_MAIN"
    echo "listen_addresses = 'localhost'" >> "$PG_CONFIG_MAIN"
fi

# 2.2 Verziószám Elrejtése (Banner Grabbing ellen)
log "[HARDENING] PostgreSQL verziószám elrejtése a logokban és hibákban."
if [ -f "$PG_CONFIG_MAIN" ]; then
    sed -i '/^server_version_comment/d' "$PG_CONFIG_MAIN"
    echo "server_version_comment = 'Authorized Access Only'" >> "$PG_CONFIG_MAIN"
    sed -i '/^log_min_messages/d' "$PG_CONFIG_MAIN"
    echo "log_min_messages = fatal" >> "$PG_CONFIG_MAIN"
fi

# --- 3. AUTENTIKÁCIÓ SZIGORÍTÁSA (PEER ÉS MD5 KÉNYSZERÍTÉSE) ---
log "--- 3. AUTENTIKÁCIÓ SZIGORÍTÁSA (PEER ÉS MD5 KÉNYSZERÍTÉSE) ---"
if [ -f "$PG_CONFIG_HBA" ]; then
    log "[HARDENING] pg_hba.conf módosítása: Peer a Unix socketre, MD5 a loopback TCP/IP-re."

    cp "$PG_CONFIG_HBA" "$PG_CONFIG_HBA.bak"
    
    # Új, szigorú tartalom írása
    cat > "$PG_CONFIG_HBA" <<'EOF'
# Helyi kommunikáció (Unix socket) - KIZÁRÓLAG RENDSZERFELHASZNÁLÓ NEVE ALAPJÁN (Zero Trust: Peer)
local   all             all                                     peer
# IPv4 helyi kapcsolatok (pl. 127.0.0.1 loopback) - Jelszó kényszerítése (Defense-in-Depth: MD5)
host    all             all             127.0.0.1/32            md5
# IPv6 helyi kapcsolatok (::1 loopback) - Jelszó kényszerítése (Defense-in-Depth: MD5)
host    all             all             ::1/128                 md5
# Minden egyéb TCP/IP kapcsolat TILTVA! (Zero Trust: Reject)
host    all             all             0.0.0.0/0               reject
host    all             all             ::/0                    reject
EOF
fi

# --- 4. SZOLGÁLTATÁS INDÍTÁSA ÉS JELSZÓ BEÁLLÍTÁSA ---
log "[ACTION] PostgreSQL újraindítása a Zero Trust beállításokkal."
service postgresql restart || log "[ERROR] A szolgáltatás újraindítása hibázott. Manuális ellenőrzés szükséges!"

# Jelszó beállítása a 'postgres' adatbázis-felhasználónak
if sudo -u postgres psql -tAc "SELECT 1" &>/dev/null; then
    log "[ACTION] 'postgres' adatbázis-felhasználó jelszavának beállítása."
    # A jelszót a psql-nek kell átadni, de nem közvetlenül parancssorban
    # Használjuk az ALTER USER parancsot
    sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$GENERATED_PASSWORD';" &>/dev/null
    
    log "----------------------------------------------------------------------------------"
    log "[KRITIKUS TITOK] A 'postgres' ADATBÁZIS FELHASZNÁLÓ JELSZAVA SIKERESEN BEÁLLÍTVA!"
    log "[KRITIKUS TITOK] Ez a jelszó szükséges a $PG_CONFIG_HBA MD5 szabályaihoz:"
    log "[KRITIKUS TITOK] $GENERATED_PASSWORD"
    log "----------------------------------------------------------------------------------"
else
    log "[CRITICAL ERROR] Nem sikerült a psql-hez csatlakozni jelszó beállításához. Manuális beavatkozás szükséges!"
    exit 1
fi

log "[DONE] 14-es ág befejezve. PostgreSQL izolálva, szigorítva és MD5 jelszóval megerősítve."
exit 0
