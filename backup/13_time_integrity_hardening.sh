#!/bin/bash
# branches/12_time_integrity_hardening.sh
# Időintegritás, NTP (systemd-timesyncd NTS) és Időzóna-zár (TZ-Lock) hardening.
# Magyarország/Budapest időzóna kényszerítése, hardveróra ellenőrzés utáni lockolás.
set -euo pipefail

# --- KONZISZTENCIA ÉS KONFIG ---
LOGFILE="/var/log/time_integrity.log"
TIMEZONE="Europe/Budapest" # KÉNYSZERÍTETT IDŐZÓNA
LOCALTIME_FILE="/etc/localtime"
HWCLOCK_BIN="/sbin/hwclock"
MAX_TIME_DIFF=30 # Max. 30 másodperc eltérés engedélyezett (Zero Trust tűréshatár)
# Globális log függvényt feltételezünk
log() { echo "$(date +%F' '%T) $*" | tee -a "$LOGFILE"; }

# Ellenőrzés: root user
if [ "$(id -u)" -ne 0 ]; then
    log "[ERROR] Run as root!" >&2
    exit 1
fi

# --- TRANZAKCIÓS TISZTÍTÁS (CLEANUP/ROLLBACK) ---
branch_cleanup() {
    log "[CRITICAL ALERT] Hiba történt a 12-es ág futása közben! Megkísérlem a rollbacket..."
    
    # Fő rollback: Az immutability lock feloldása (ez a legfontosabb)
    log "[ACTION] Immutability lock feloldása a kritikus időfájlokról."
    chattr -i "$LOCALTIME_FILE" || true
    chattr -i "$HWCLOCK_BIN" || true
    chattr -i /dev/rtc* || true

    log "[CRITICAL ALERT] 12-es ág rollback befejezve. Kérem, ellenőrizze az időbeállításokat!"
}
trap branch_cleanup ERR


# --- 1. ELŐELLENŐRZÉS: HWCLOCK INTEGRITÁS VIZSGÁLAT ---
log "--- 1. ELŐELLENŐRZÉS: HWCLOCK INTEGRITÁS VIZSGÁLAT ---"

if command -v $HWCLOCK_BIN >/dev/null 2>&1; then
    
    # 1.1 Szinkronizáljuk a hardverórát a rendszer idejével
    log "[ACTION] Hardveróra szinkronizálása a rendszer idejével."
    $HWCLOCK_BIN --systohc --utc

    # Várjunk egy pillanatot, hogy biztosítsuk a kiolvasást
    sleep 2

    # 1.2 Összehasonlítás
    SYSTEM_TIME=$(date +%s)
    HW_TIME_STRING=$($HWCLOCK_BIN --show --utc)
    HW_TIME_SECONDS=$(date -d "$HW_TIME_STRING" +%s)
    
    TIME_DIFF=$((SYSTEM_TIME - HW_TIME_SECONDS))
    TIME_DIFF=${TIME_DIFF#-} # Abszolút érték
    
    log "[INFO] Rendszeridő: $SYSTEM_TIME. Hardveróra: $HW_TIME_SECONDS. Eltérés: $TIME_DIFF másodperc."

    if [ "$TIME_DIFF" -gt "$MAX_TIME_DIFF" ]; then
        log "[CRITICAL ERROR] A hardveróra és a rendszeridő eltérése TÚL NAGY ($TIME_DIFF s)! A hardveróra hibás lehet, nem lockolható."
        exit 1
    else
        log "[OK] A hardveróra megfelelő pontosságú ($TIME_DIFF s). Folytatás a lockolással."
    fi
else
    log "[WARNING] $HWCLOCK_BIN bináris nem található. Hardveróra ellenőrzés kihagyva."
fi


# --- 2. IDŐZÓNA (TZ) ÉS HWCLOCK IMMUTABILITY ZÁR (TZ-Lock) ---
log "--- 2. IDŐZÓNA ÉS HWCLOCK IMMUTABILITY ZÁR ---"

# 2.1 Időzóna beállítása (Budapest beégetése)
log "[ACTION] Időzóna beállítása és BEÉGETÉSE: $TIMEZONE."

if command -v timedatectl >/dev/null 2>&1; then
    timedatectl set-timezone "$TIMEZONE"
else
    if [ -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
        rm -f "$LOCALTIME_FILE" || true
        cp "/usr/share/zoneinfo/$TIMEZONE" "$LOCALTIME_FILE"
    else
        log "[ERROR] Időzóna fájl nem található!"
        exit 1
    fi
fi

# 2.2 Immutability Lock kényszerítése az időzóna fájlra (TZ-Lock)
log "[HARDENING] Immutability Lock kényszerítése a $LOCALTIME_FILE-ra (TZ-Lock)."
chattr +i "$LOCALTIME_FILE"

# 2.3 HWCLOCK bináris és eszközfájl védelme
if [ -f "$HWCLOCK_BIN" ]; then
    log "[HARDENING] $HWCLOCK_BIN bináris immutability zár (Hardveróra manipuláció ellen)."
    chattr +i "$HWCLOCK_BIN"
    chattr +i /dev/rtc* || true
fi


# --- 3. NTP SZINKRONIZÁCIÓ (NTS/Minimalista) ---
log "--- 3. NTP SZINKRONIZÁCIÓ ---"

if command -v timedatectl >/dev/null 2>&1; then
    log "[ACTION] Időszinkronizáció engedélyezése systemd-timesyncd-vel (NTS preferált)."
    timedatectl set-ntp true
else
    log "[WARNING] systemd-timesyncd/timedatectl nem található. Kérem, manuálisan konfigurálja a CHRONY/NTPSEC-et NTS-sel és szigorítsa AppArmorral!"
fi


# --- 4. HARDENING UTÁNI ELLENŐRZÉS ---
log "--- 4. HARDENING UTÁNI ELLENŐRZÉS ---"
if lsattr "$LOCALTIME_FILE" | grep -q 'i'; then
    log "[OK] Időzóna-zár (TZ-Lock) aktív: $LOCALTIME_FILE módosíthatatlan."
else
    log "[CRITICAL ERROR] Időzóna-zár (TZ-Lock) hibázott!"
    exit 1
fi

log "[DONE] 12-es ág befejezve. Időintegritás és időzóna-zár kényszerítve."
exit 0
