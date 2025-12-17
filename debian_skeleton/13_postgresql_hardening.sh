#!/bin/bash
# 14_postgresql_hardening.sh - PostgreSQL telepítése, hálózati izolációja, és a 'postgres' adatbázis-felhasználó SZIGORÚ jelszó beállítása.

# set -euo pipefail garantálja, hogy hiba esetén a TRAP lefut
set -euo pipefail

# --- KONZISZTENCIA ÉS KONFIG ---
LOGFILE="/var/log/postgresql_hardening.log"
PG_VERSION=$(dpkg-query -W -f='${Version}' postgresql | cut -d'.' -f1 || echo "15")

PG_CONFIG_MAIN="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
PG_CONFIG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
HBA_BACKUP_FILE="${PG_CONFIG_HBA}.bak.14"

# Generáljuk a Titkot:
GENERATED_PASSWORD=$(openssl rand -base64 32) # PostgreSQL Jelszó

# Globális log függvényt feltételezünk
log() { echo "$(date +%F' '%T) $*" | tee -a "$LOGFILE"; }

# --- TRANZAKCIÓS TISZTÍTÁS (CLEANBACK) ---
function branch_cleanup() {
    log "[CRITICAL ALERT] Hiba történt a 14-es ág futása közben! Megkísérlem a rollbacket..."
    
    # 1. pg_hba.conf visszaállítása
    if [ -f "$HBA_BACKUP_FILE" ]; then
        cp "$HBA_BACKUP_FILE" "$PG_CONFIG_HBA"
        rm -f "$HBA_BACKUP_FILE" 2>/dev/null
        log "   -> pg_hba.conf sikeresen visszaállítva."
    fi

    # 2. Csomagok eltávolítása
    log "[ACTION] PostgreSQL csomagok eltávolítása (purge)."
    apt-get purge -y "postgresql-$PG_VERSION" postgresql-client || true
    rm -rf "/var/lib/postgresql/$PG_VERSION/main" || true
    log "[CRITICAL ALERT] 14-es ág rollback befejezve."
    
    # 3. Végleges törlés a memóriából
    unset GENERATED_PASSWORD
    
    exit 1
}
trap branch_cleanup ERR

# --- 1. TELEPÍTÉS ÉS BIZTONSÁGOS ALAPOK ---
log "--- 1. TELEPÍTÉS ÉS BIZTONSÁGOS ALAPOK ---"
log "[ACTION] PostgreSQL telepítése (server és client)."
apt-get install -y --no-install-recommends "postgresql-$PG_VERSION" postgresql-client-"$PG_VERSION"

# --- 2. HÁLÓZATI IZOLÁCIÓ ÉS VERZIÓ ELREJTÉSE (Konfiguráció) ---
if [ -f "$PG_CONFIG_MAIN" ]; then
    log "[HARDENING] listen_addresses beállítása KIZÁRÓLAG localhost-ra."
    sed -i '/^listen_addresses/d' "$PG_CONFIG_MAIN"
    echo "listen_addresses = 'localhost'" >> "$PG_CONFIG_MAIN"
    
    log "[HARDENING] PostgreSQL verziószám elrejtése a logokban és hibákban."
    sed -i '/^server_version_comment/d' "$PG_CONFIG_MAIN"
    echo "server_version_comment = 'Authorized Access Only'" >> "$PG_CONFIG_MAIN"
    sed -i '/^log_min_messages/d' "$PG_CONFIG_MAIN"
    echo "log_min_messages = fatal" >> "$PG_CONFIG_MAIN"
fi

# --- 3. AUTENTIKÁCIÓ SZIGORÍTÁSA (HBA) ---
if [ -f "$PG_CONFIG_HBA" ]; then
    log "[HARDENING] pg_hba.conf módosítása."
    cp "$PG_CONFIG_HBA" "$HBA_BACKUP_FILE" # Backup a rollbackhez!
    
    cat > "$PG_CONFIG_HBA" <<'EOF'
# Helyi kommunikáció (Unix socket) - KIZÁRÓLAG RENDSZERFELHASZNÁLÓ NEVE ALAPJÁN (Zero Trust: Peer)
local   all             all                                     peer
# IPv4 helyi kapcsolatok - Jelszó kényszerítése (MD5)
host    all             all             127.0.0.1/32            md5
# IPv6 helyi kapcsolatok - Jelszó kényszerítése (MD5)
host    all             all             ::1/128                 md5
# Minden egyéb TCP/IP kapcsolat TILTVA! (Zero Trust: Reject)
host    all             all             0.0.0.0/0               reject
host    all             all             ::/0                    reject
EOF
fi

# --- 4. SZOLGÁLTATÁS INDÍTÁSA ÉS JELSZÓ BEÁLLÍTÁSA ---
log "[ACTION] PostgreSQL újraindítása a Zero Trust beállításokkal."
service postgresql restart # Hiba esetén megszakad és fut a trap!

# Jelszó beállítása a 'postgres' adatbázis-felhasználónak
if sudo -u postgres psql -tAc "SELECT 1" &>/dev/null; then
    log "[ACTION] 'postgres' adatbázis-felhasználó jelszavának beállítása."
    
    # 4a. Jelszó beállítása az adatbázisban
    sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$GENERATED_PASSWORD';" &>/dev/null
    
    # 4b. Jelszó kiírása a STDOUT-ra és azonnali mentési kérelem (zero-trust audit)
    log "[TITOK KEZELÉS] A PostgreSQL jelszó sikeresen beállítva. Kérem, mentse el a füzetébe!"
    log "----------------------------------------------------------------------------------"
    echo "[POSTGRES JELSZÓ] -> $GENERATED_PASSWORD" # Direkt kiírás a terminálra
    log "----------------------------------------------------------------------------------"
    
    # KRITIKUS MEGSZAKÍTÁS: ENTER kérés a feljegyzés idejére
    read -r -p "!!! KRITIKUS SZAKASZ: Kérem, írja fel a jelszót, majd nyomja meg az ENTER-t a folytatáshoz... "
    
    # 4c. Végleges törlés a memóriából (CRITICAL ZERO-TRUST LÉPÉS)
    unset GENERATED_PASSWORD

else
    log "[CRITICAL ERROR] Nem sikerült a psql-hez csatlakozni jelszó beállításához. Manuális beavatkozás szükséges!"
    exit 1
fi

# 5. COMMIT: Sikeres futás, backup törlése
rm -f "$HBA_BACKUP_FILE"

log "[DONE] 14-es ág befejezve. PostgreSQL izolálva, és a jelszó kiírva a mentéshez."
exit 0
