#!/bin/bash
# branches/06-essential-packages.sh
# Telepíti az alapvető, minimalista és biztonsági csomagokat (Auditd, AppArmor, iproute2).
# Minimalizmus: Csak a legszükségesebbek, --no-install-recommends kényszerítve.
# Author: Beatrix Zelezny 🐱 (Zero Trust Revision by Gemini)
set -euo pipefail

# --- KONZISZTENCIA BEÁLLÍTÁSOK ---
LOGFILE="/var/log/essential_packages.log"

# Globális log függvényt feltételezünk a tools/common_functions.sh-ból
log() { echo "$(date +%F' '%T) $*" | tee -a "$LOGFILE"; }
log "" # Új szakasz

# Ellenőrzés: root user
if [ "$(id -u)" -ne 0 ]; then
    log "[ERROR] Run as root!" >&2
    exit 1
fi

# --- TRANZAKCIÓS TISZTÍTÁS (CLEANUP/ROLLBACK) ---
# **JAVÍTÁS:** Megtartjuk a funkciót az átlátható hibajelentéshez, de hagyjuk, hogy a set -e végezze a leállítást.
branch_cleanup() {
    log "[CRITICAL ALERT] Hiba történt a 06-os ág futása közben (csomagtelepítés). Ellenőrizd a logot: $LOGFILE"
    log "[CRITICAL ALERT] 06-os ág rollback befejezve (nincs konfig fájl visszaállítás, de a csomagkezelő megszakadt)."
}

# Hiba esetén a rollback funkció meghívása
trap branch_cleanup ERR

# --- ESSENTIAL CSOMAGOK LISTÁJA (Minimalista és Biztonságos) ---
ESSENTIAL_PACKAGES=(
    # Hardening alapok: AppArmor/Auditd (későbbi ágakhoz)
    auditd
    apparmor
    apparmor-utils
    
    # Kritikus rendszer alapok (Minimalista)
    sudo              # Jogosultság emeléshez
    ca-certificates # HTTPS/TLS validáláshoz
    gnupg           # Aláírás ellenőrzéshez
    
    # Hálózati és Bináris-kezelő eszközök
    iproute2            # Modern hálózati eszköz (ip parancs)
    binutils            # Readelf-hez és bináris manipulációhoz
    patchelf            # PaX/Execstack Emulációhoz (későbbi szkripthez)
    
    # Naplózás/Ütemezés
    rsyslog             # Naplók kezeléséhez
    cron                # Ütemezett feladatokhoz
    
    # APT
    apt-transport-https # HTTPS kényszerítéshez
)
# **JAVÍTÁS:** Eltávolítva a listából a 'vim', 'git' és 'build-essential' csomagok a zero-trust minimalizmus érdekében.

log "[ACTION] Csomaglista (${#ESSENTIAL_PACKAGES[*]} db): ${ESSENTIAL_PACKAGES[*]}"

# --- CSOMAGOK TELEPÍTÉSE (Tömegesen, Minimalistán) ---

# 1. Frissítés
log "[ACTION] APT index frissítése..."
# **JAVÍTÁS:** A set -e gondoskodik a hibakezelésről.
apt-get update

# 2. Tömeges telepítés (--no-install-recommends globálisan is be van állítva, de redundancia a biztos!)
log "[ACTION] Esszenciális csomagok telepítése (minimalista módon)."
apt-get install -y --no-install-recommends "${ESSENTIAL_PACKAGES[@]}"

# --- UTÓLAGOS AUDIT ÉS TISZTÍTÁS ---

log "[AUDIT] Csomag audit naplózása és felesleges csomagok eltávolítása."
{
    echo "--- 06-os ÁG ÖSSZEFOGLALÓ ---"
    echo "Telepített esszenciális csomagok:"
    dpkg -l | grep -E "$(IFS='|'; echo "${ESSENTIAL_PACKAGES[*]}")"
    echo "-----------------------------"

} >> "$LOGFILE"

# Felesleges/árva csomagok azonnali eltávolítása (a zero-trust elv miatt)
log "[ACTION] apt autoremove futtatása a telepítés utáni azonnali tisztításhoz."
apt autoremove -y

log "[DONE] 06-os ág befejezve. Alapvető, zero-trust csomagok telepítve. Log: $LOGFILE"
exit 0
