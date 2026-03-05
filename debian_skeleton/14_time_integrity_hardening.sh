#!/bin/bash
# branches/12_time_integrity_hardening.sh
# Időintegritás, NTP (NTPsec/Chrony) és Időzóna-zár (TZ-Lock) hardening.
# Magyarország/Budapest időzóna kényszerítése, és kritikus lockolás.
set -euo pipefail

# --- KONZISZTENCIA ÉS KONFIG ---
LOGFILE="/var/log/time_integrity.log"
TIMEZONE="Europe/Budapest" # KÉNYSZERÍTETT IDŐZÓNA
LOCALTIME_FILE="/etc/localtime"
HWCLOCK_BIN="/sbin/hwclock"
RTC_FILES="/dev/rtc /dev/rtc0 /dev/rtc1" # A kritikus eszközfájlok listája
MAX_TIME_DIFF=60 # Max. 60 másodperc eltérés engedélyezett (Zero Trust tűréshatár)
# Globális log függvényt feltételezünk
log() { echo "$(date +%F' '%T) $*" | tee -a "$LOGFILE"; }
log "" # Új szakasz

# Ellenőrzés: root user
if [ "$(id -u)" -ne 0 ]; then
    log "[ERROR] Run as root!" >&2
    exit 1
fi

# Feloldó funkció (immutability zárak feloldása)
function unlock_file() {
    local file="$1"
    if command -v chattr &> /dev/null; then
        chattr -i "$file" 2>/dev/null || true
    fi
}

# --- TRANZAKCIÓS TISZTÍTÁS (CLEANUP/ROLLBACK) ---
function branch_cleanup() {
    log "[CRITICAL ALERT] Hiba történt a 12-es ág futása közben! Megkísérlem a rollbacket..."
    
    # Fő rollback: Az immutability lock feloldása a kritikus fájlokról
    log "[ACTION] Immutability lock feloldása a kritikus időfájlokról."
    unlock_file "$LOCALTIME_FILE" 
    # **JAVÍTOTT: HWCLOCK és RTC fájlok feloldása**
    unlock_file "$HWCLOCK_BIN"
    for rtc in $RTC_FILES; do
        unlock_file "$rtc"
    done

    log "[CRITICAL ALERT] 12-es ág rollback befejezve. Kérem, ellenőrizze az időbeállításokat!"
    exit 1
}
trap branch_cleanup ERR


# --- 1. ELŐELLENŐRZÉS: HWCLOCK INTEGRITÁS VIZSGÁLAT ---
log "--- 1. ELŐELLENŐRZÉS: HWCLOCK INTEGRITÁS VIZSGÁLAT (HARDENING) ---"

if command -v $HWCLOCK_BIN >/dev/null 2>&1; then
    
    # 1.0 Hardveróra és bináris feloldása a szinkronizációhoz (ha le volt zárva)
    unlock_file "$HWCLOCK_BIN"
    for rtc in $RTC_FILES; do
        unlock_file "$rtc"
    done

    # 1.1 Hardveróra szinkronizálása a rendszer idejével
    log "[ACTION] Hardveróra szinkronizálása a rendszer idejével (UTC)."
    $HWCLOCK_BIN --systohc --utc || log "[WARNING] hwclock szinkronizálás sikertelen, de folytatom."

    # 1.2 Időeltérés ellenőrzése
    log "[INFO] Hardveróra és rendszeridő eltérésének ellenőrzése."

    if ! TIME_DIFF_S=$($HWCLOCK_BIN --hctosys --noadjfile --compare | awk '/System time/ {print $NF; exit}' | tr -d '()' 2>/dev/null); then
        log "[WARNING] A hardveróra kiolvasása nem adta vissza a pontos eltérést. Folytatom a lockolást."
        TIME_DIFF_S=0 # Folytatjuk, ha nem tudtuk mérni
    fi
    
    log "[INFO] Mért időeltérés: $TIME_DIFF_S másodperc."

    if [[ "$TIME_DIFF_S" != *[^0-9]* && "$TIME_DIFF_S" -gt "$MAX_TIME_DIFF" ]]; then
        log "[CRITICAL ERROR] A hardveróra és a rendszeridő eltérése TÚL NAGY ($TIME_DIFF_S s)! A hardveróra hibás lehet, nem lockolható."
        exit 1
    fi
else
    log "[WARNING] $HWCLOCK_BIN bináris nem található. Hardveróra ellenőrzés kihagyva."
fi


# --- 2. IDŐZÓNA (TZ) ÉS HWCLOCK IMMUTABILITY ZÁR (TZ-Lock) ---
log "--- 2. IDŐZÓNA ÉS HWCLOCK IMMUTABILITY ZÁR ---"

# 2.1 Időzóna beállítása (Budapest beégetése)
log "[ACTION] Időzóna beállítása és BEÉGETÉSE: $TIMEZONE."

if [ -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
    unlock_file "$LOCALTIME_FILE"
    rm -f "$LOCALTIME_FILE"
    cp "/usr/share/zoneinfo/$TIMEZONE" "$LOCALTIME_FILE"
else
    log "[ERROR] Időzóna fájl /usr/share/zoneinfo/$TIMEZONE nem található! Kézi ellenőrzés szükséges."
    exit 1
fi

# 2.2 Immutability Lock kényszerítése az időzóna fájlra (TZ-Lock)
log "[HARDENING] Immutability Lock kényszerítése a $LOCALTIME_FILE-ra (TZ-Lock)."
if command -v chattr &> /dev/null; then
    chattr +i "$LOCALTIME_FILE"
else
    log "[CRITICAL ERROR] chattr parancs nem található! A TZ-Lock nem érvényesíthető. Kézi beavatkozás szükséges!"
    exit 1
fi

# **VISSZAÁLLÍTVA: HWCLOCK bináris és eszközfájl védelme a támadások ellen.**
if [ -f "$HWCLOCK_BIN" ]; then
    log "[HARDENING] $HWCLOCK_BIN bináris immutability zár (Hardveróra manipuláció ellen)."
    chattr +i "$HWCLOCK_BIN"
    log "[HARDENING] /dev/rtc* eszközfájlok immutability zár (Közvetlen manipuláció ellen)."
    for rtc in $RTC_FILES; do
        if [ -c "$rtc" ]; then # Csak karakteres eszközfájlt zárjunk
            chattr +i "$rtc"
        fi
    done
fi


# --- 3. NTP SZINKRONIZÁCIÓ (NTPsec/Chrony előkészítés) ---
log "--- 3. NTP SZINKRONIZÁCIÓ ---"

log "[WARNING] systemd-timesyncd nem használható. Kérem, a következő ágakban konfigurálja a CHRONY-t vagy NTPSEC-et NTS-sel a Zero-Trust időszinkronizációhoz."


# --- 4. HARDENING UTÁNI ELLENŐRZÉS ---
log "--- 4. HARDENING UTÁNI ELLENŐRZÉS ---"
if lsattr "$LOCALTIME_FILE" | grep -q 'i'; then
    log "[OK] Időzóna-zár (TZ-Lock) aktív: $LOCALTIME_FILE módosíthatatlan."
else
    log "[CRITICAL ERROR] Időzóna-zár (TZ-Lock) hibázott!"
    exit 1
fi
if [ -f "$HWCLOCK_BIN" ] && lsattr "$HWCLOCK_BIN" | grep -q 'i'; then
    log "[OK] $HWCLOCK_BIN bináris immutability zár aktív."
fi

log "[DONE] 12-es ág befejezve. Időintegritás és Hardveróra-zár kényszerítve."
exit 0
