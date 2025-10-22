#!/bin/bash
# branches/07-sysv-init-hardening.sh
# SysV Init Hardening: Biztosítja a SysV Init használatát a systemd helyett.
# Szolgáltatások minimalista runlevel beállítása (hardcore minimalizmus).
# ZERO TRUST: Explicit Systemd-mentes környezet.
set -euo pipefail

# --- KONZISZTENCIA BEÁLLÍTÁSOK ---
LOGFILE="/var/log/sysv_init_hardening.log"
# Globális log függvényt feltételezünk
log() { echo "$(date +%F' '%T) $*" | tee -a "$LOGFILE"; }
log "" # Új szakasz

# Ellenőrzés: root user
if [ "$(id -u)" -ne 0 ]; then
    log "[ERROR] Run as root!" >&2
    exit 1
fi

# --- KONFIGURÁCIÓ ---
# Engedélyezni kívánt Zero-Trust szolgáltatások
SERVICES_TO_ENABLE=(
    ssh         # Távmenedzsmenthez
    cron        # Ütemezett feladatokhoz
    rsyslog     # Audit és rendszer naplózás
    networking  # Hálózati interface-ek
)
# Tiltani kívánt szolgáltatások (Zero-Trust alapon)
SERVICES_TO_DISABLE=(
    exim4         # Kritikus: Zero-Trust fa elején tiltva.
)

# --- TRANZAKCIÓS TISZTÍTÁS (CLEANUP/ROLLBACK) ---
function branch_cleanup() {
    log "[CRITICAL ALERT] Hiba történt a 07-es ág futása közben! Megkísérlem a rollbacket..."
    
    # Inverz művelet: A bekapcsolt szolgáltatások visszatiltása (update-rc.d disable)
    if command -v update-rc.d >/dev/null 2>&1; then
        for svc in "${SERVICES_TO_ENABLE[@]}"; do
            log "   -> $svc szolgáltatás tiltása (rollback)."
            update-rc.d "$svc" disable || true
        done
    fi
    
    log "[CRITICAL ALERT] 07-es ág rollback befejezve. Kézi ellenőrzés szükséges!"
    exit 1
}

# Hiba esetén a rollback funkció meghívása
trap branch_cleanup ERR

# --- 1. SYSV INIT KÉNYSZERÍTÉSE ÉS BEÁLLÍTÁSA ---
log "1. SysV init és alapvető runlevel beállító eszközök telepítése."
# A sysvinit-core csomag gondoskodik a systemd helyettesítéséről
apt-get install -y --no-install-recommends sysvinit-core sysv-rc

# --- 2. SZOLGÁLTATÁSOK RUNLEVEL HARDENINGJE ---

# 2a. Zero Trust: Felesleges szolgáltatások explicit tiltása
for svc in "${SERVICES_TO_DISABLE[@]}"; do
    if [ -f "/etc/init.d/$svc" ]; then
        log "[ACTION] $svc szolgáltatás **EXPLICIT TILTÁSA**."
        # Hiba esetén a set -e aktiválja a rollbacket!
        update-rc.d "$svc" disable
    else
        log "[INFO] $svc init szkript nem található (valószínűleg nem is települt), kihagyva a tiltást."
    fi
done

# 2b. Zero Trust: Csak a szükséges szolgáltatások engedélyezése
log "2b. Zero Trust: Csak a szükséges szolgáltatások engedélyezése."
for svc in "${SERVICES_TO_ENABLE[@]}"; do
    if [ -f "/etc/init.d/$svc" ]; then
        # Explicit runlevel beállítás (2, 3, 5)
        log "[ACTION] $svc szolgáltatás engedélyezése (runlevel 2, 3, 5)."
        # Hiba esetén a set -e aktiválja a rollbacket!
        update-rc.d "$svc" enable 2 3 5
    else
        log "[WARNING] $svc init szkript nem található, kihagyva."
    fi
done

# --- 3. ELLENŐRZÉS (Zero-Trust Konklúzió) ---
log "[INFO] Systemd futásidejű ellenőrzés kihagyva, mivel a csomagok tiltva vannak."
log "[DONE] 07-es ág befejezve. SysV Init kényszerítve és szolgáltatások beállítva."
exit 0
