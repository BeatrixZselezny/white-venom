#!/bin/bash
# branches/06-essential-packages.sh
# Telepíti az alapvető, minimalista és biztonsági csomagokat (Auditd, AppArmor, iproute2).
# Minimalizmus: Csak a legszükségesebbek, --no-install-recommends kényszerítve.
# Author: Beatrix Zelezny 🐱 (Zero Trust Revision by Gemini)
set -euo pipefail

# --- KONZISZTENCIA BEÁLLÍTÁSOK ---
LOGFILE="/var/log/essential_packages.log"

# Globális log függvényt feltételezünk a tools/common_functions.sh-ból
log() { echo "$(date +%F' '%T) $*"; }

# Ellenőrzés: root user
if [ "$(id -u)" -ne 0 ]; then
    log "[ERROR] Run as root!" >&2
    exit 1
fi

# --- TRANZAKCIÓS TISZTÍTÁS (CLEANUP/ROLLBACK) ---
branch_cleanup() {
    log "[ALERT] Hiba történt a 06-os ág futása közben (csomagtelepítés). Ellenőrizd a logot: $LOGFILE"
    # Ez az ág nem ír konfigurációs fájlt, így a rollback a tiszta kilépés a feladata.
    log "[ALERT] 06-os ág rollback befejezve (nincs konfig fájl visszaállítás)."
}

# Hiba esetén a rollback funkció meghívása
trap branch_cleanup ERR

# --- ESSENTIAL CSOMAGOK LISTÁJA (Minimalista és Biztonságos) ---
ESSENTIAL_PACKAGES=(
    # Hardening alapok: AppArmor/Auditd (későbbi ágakhoz)
    auditd
    apparmor
    apparmor-utils
    
    # Hálózati és rendszer alapok (Minimalista IP-kezelés)
    sudo
    vim
    git
    ca-certificates
    binutils
    patchelf
    gnupg
    build-essential
    apt-transport-https # HTTPS kényszerítéshez szükséges (telepítve a debootstrapban)
    iproute2            # Modern hálózati eszköz (ip parancs)
    
    # Naplózás/Ütemezés
    rsyslog
    cron
)
# Megjegyzés: iputils-ping és net-tools eltávolítva a minimalizmus érdekében!

log "[ACTION] Csomaglista: ${ESSENTIAL_PACKAGES[*]}"

# --- CSOMAGOK TELEPÍTÉSE (Tömegesen, Minimalistán) ---

# 1. Frissítés
log "[ACTION] APT index frissítése..."
apt-get update

# 2. Tömeges telepítés (--no-install-recommends globálisan is be van állítva)
log "[ACTION] Esszenciális csomagok telepítése (minimalista módon)."
# -y: feltételezzük az igent a parancssorból
apt-get install -y --no-install-recommends "${ESSENTIAL_PACKAGES[@]}"

# --- UTÓLAGOS AUDIT (Mi húzta fel?) ---

log "[AUDIT] Függőségi audit a logfájlba ($LOGFILE)..."
{
    echo "--- FÜGGŐSÉGEK AUDITÁLÁSA ---"
    for pkg in "${ESSENTIAL_PACKAGES[@]}"; do
        echo "Dependencies for $pkg:"
        # aptitude why - megnézi miért kell a csomag
        # ha nincs aptitude, apt-cache rdepends is megteszi
        apt-cache rdepends "$pkg" | head -n 5 || echo "  (apt-cache rdepends hiba)"
        echo ""
    done
    echo "--- DEBORPHAN ELLENŐRZÉS (Felesleges csomagok) ---"
    # Felesleges / orphan csomagok ellenőrzése (deborphan-t telepíteni kell, de nem muszáj essential csomagnak lennie)
    if command -v deborphan >/dev/null 2>&1; then
        deborphan --all-packages
    else
        echo "deborphan nincs telepítve, kihagyva."
    fi
    echo "--- AUTOREMOVE ELLENŐRZÉS ---"
    apt autoremove -s
} >> "$LOGFILE"

log "[DONE] 06-os ág befejezve. Alapvető csomagok telepítve és auditálva. Log: $LOGFILE"
exit 0
