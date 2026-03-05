#!/bin/bash
# branches/07-sysv-init-hardening.sh
# SysV Init Hardening: Biztosítja a SysV Init használatát a systemd helyett.
# Szolgáltatások minimalista runlevel beállítása (hardcore minimalizmus).
# Author: Beatrix Zelezny 🐱 (Zero Trust Revision by Gemini)
set -euo pipefail

# --- KONZISZTENCIA BEÁLLÍTÁSOK ---
LOGFILE="/var/log/sysv_init_hardening.log"
# Globális log függvényt feltételezünk a tools/common_functions.sh-ból
log() { echo "$(date +%F' '%T) $*"; }

# Ellenőrzés: root user
if [ "$(id -u)" -ne 0 ]; then
    log "[ERROR] Run as root!" >&2
    exit 1
fi

# --- TRANZAKCIÓS TISZTÍTÁS (CLEANUP/ROLLBACK) ---
branch_cleanup() {
    log "[ALERT] Hiba történt a 07-es ág futása közben. Ellenőrizd a logot: $LOGFILE"
    # Ez az ág init szkripteket konfigurál (update-rc.d). Komplex rollback nem szükséges.
    log "[ALERT] 07-es ág rollback befejezve (tiszta kilépés)."
}

# Hiba esetén a rollback funkció meghívása
trap branch_cleanup ERR

# --- 1. SYSV INIT KÉNYSZERÍTÉSE ÉS BEÁLLÍTÁSA ---

log "[ACTION] SysV init és alapvető runlevel beállító eszközök telepítése."
# A sysvinit-core csomag gondoskodik a systemd helyettesítéséről
apt-get install -y --no-install-recommends sysvinit-core sysv-rc

# --- 2. SZOLGÁLTATÁSOK RUNLEVEL HARDENINGJE ---
# Zero Trust elv: Csak a ténylegesen szükséges szolgáltatások bekapcsolása
# a szokásos 2, 3, 5 runlevelben (multi-user, grafikus).
# Az Unboundot később állítjuk be, miután a konfig fájlja is megvan.

SERVICES_TO_ENABLE=(
    ssh         # Távmenedzsmenthez
    cron        # Ütemezett feladatokhoz
    rsyslog     # Audit és rendszer naplózás
    networking  # Hálózati interface-ek
)

for svc in "${SERVICES_TO_ENABLE[@]}"; do
    if [ -f "/etc/init.d/$svc" ]; then
        # Explicit runlevel beállítás (nem 'defaults')
        log "[ACTION] $svc szolgáltatás engedélyezése (runlevel 2, 3, 5)."
        update-rc.d "$svc" enable 2 3 5
    else
        log "[WARNING] $svc init szkript nem található, kihagyva."
    fi
done

# --- 3. ELLENŐRZÉS ---
log "[AUDIT] Systemd folyamatok ellenőrzése..."
if pgrep systemd >/dev/null; then
    log "[CRITICAL ERROR] systemd processes running after SysV init config! Abort." | tee -a "$LOGFILE"
    exit 1
else
    log "[OK] Nincs futó systemd folyamat. SysV init aktív."
fi

log "[DONE] 07-es ág befejezve. SysV Init kényszerítve és szolgáltatások beállítva."
exit 0
