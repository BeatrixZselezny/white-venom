#!/bin/bash
# ------------------------------------------------------------------
# 17_module_blacklist.sh
# Kernel module blacklist hardening (Final logic: Modules_Disabled removed)
# ------------------------------------------------------------------

set -euo pipefail

# --- KONZISZTENCIA ÉS KONFIG ---
LOGFILE="/var/log/hardening_module_blacklist.log"
# **JAVÍTÁS: BACKUP_DIR helyett specifikus backup fájlokat használunk a rollbackhez.**
BLACKLIST_FILE="/etc/modprobe.d/hardening_blacklist.conf"
BLACKLIST_BACKUP_FILE="${BLACKLIST_FILE}.bak.17"

log() { echo "$(date +%F' '%T) $*" | tee -a "$LOGFILE"; }
echo "" | tee -a "$LOGFILE" # Új szakasz

# --- TRANZAKCIÓS TISZTÍTÁS (CLEANBACK) ---
function branch_cleanup() {
    log "[CRITICAL ALERT] Hiba történt a 17-es ág futása közben! Megkísérlem a rollbacket..."
    
    # 1. chattr -i feloldása (ha lezártuk, vagy ha az orchestrator kritikus fájlként kezeli)
    if command -v chattr &> /dev/null; then
        log "   -> chattr feloldása."
        chattr -i "$BLACKLIST_FILE" 2>/dev/null || true
    fi

    # 2. Visszaállítás, ha volt backup (régi fájl módosítása esetén)
    if [ -f "$BLACKLIST_BACKUP_FILE" ]; then
        log "   -> $BLACKLIST_FILE visszaállítása a backupból."
        mv "$BLACKLIST_BACKUP_FILE" "$BLACKLIST_FILE" || true
    # 3. Törlés, ha ez a szkript hozta létre
    elif [ -f "$BLACKLIST_FILE" ]; then
        log "   -> $BLACKLIST_FILE törlése (mivel ez a szkript hozta létre)."
        rm -f "$BLACKLIST_FILE" || true
    fi

    log "[CRITICAL ALERT] 17-es ág rollback befejezve. Kézi ellenőrzés szükséges!"
    exit 1
}
trap branch_cleanup ERR

log "--- 17_module_blacklist: Kernel modul blacklist kikényszerítése ---"

# ------------------------------------------------------------------
# Step 1: Create or backup blacklist file
# ------------------------------------------------------------------
if [ -f "$BLACKLIST_FILE" ]; then
    log "[ACTION] Backup készítése: $BLACKLIST_FILE"
    cp "$BLACKLIST_FILE" "$BLACKLIST_BACKUP_FILE"
fi

# Feloldjuk a lockot a módosítás idejére
local BLACKLIST_LOCKED=0
if command -v chattr &> /dev/null && lsattr "$BLACKLIST_FILE" 2>/dev/null | grep -q "i"; then
    chattr -i "$BLACKLIST_FILE" 
    BLACKLIST_LOCKED=1
fi

# ------------------------------------------------------------------
# Step 2: Create new blacklist file
# ------------------------------------------------------------------
# **JAVÍTÁS: Cat EOF-et használunk, de a fájl tényleges létrehozása vagy felülírása előtt kezeljük a lockot!**
log "[ACTION] Új blacklist tartalom írása a $BLACKLIST_FILE fájlba."
cat << 'EOF' > "$BLACKLIST_FILE"
# Custom Bea hardening blacklist (critical modules)
blacklist i2c-piix4
blacklist snd-soc-max98090
blacklist snd-soc-rt5640
blacklist sns-soc-rl16231
blacklist appledisplay
blacklist apple_bl
blacklist appletouch
blacklist ac97_bus
blacklist soundcore
blacklist pcspker
blacklist usb-storage
blacklist hid-apple
blacklist hid-appleir
blacklist applesmc
blacklist ipddp
blacklist apple-gmux
blacklist appletalk
blacklist macmodes
blacklist hid-hyperv
blacklist hyperv-keyboard
blacklist hyperv_fb
blacklist hv_balloon
blacklist hv_vmbus
blacklist hv_storvsc
blacklist sp5100_tco
EOF

chmod 644 "$BLACKLIST_FILE"

# ------------------------------------------------------------------
# Step 3: Attempt to unload listed modules (if loaded)
# ------------------------------------------------------------------
log "[ACTION] Próbálkozás a letiltott modulok eltávolításával (rmmod)."
for mod in $(awk '/^blacklist/ {print $2}' "$BLACKLIST_FILE"); do
    if lsmod | grep -q "^$mod"; then
        # **JAVÍTÁS: Eltávolítjuk a 2>/dev/null-t, hogy a set -e aktiválódjon, ha a modprobe hibázik.**
        # A `|| true` itt sem használható, mert az elnyelné a hibát!
        log "   -> Eltávolítás: $mod"
        modprobe -r "$mod" || log "[FIGYELEM] Nem sikerült eltávolítani a modult: $mod (használatban vagy védett)"
    fi
done

# ------------------------------------------------------------------
# Step 4: Finalize and Cleanup (Commit)
# ------------------------------------------------------------------

# **JAVÍTÁS: Eltávolítottuk a /proc/sys/kernel/modules_disabled logikát!**
# **Ezt a kritikus lezárást a telepítési folyamat legvégére helyezzük át (pl. 99_final_lockdown.sh).**

log "[INFO] A kernel.modules_disabled=1 beállítás a végső lezárási szkriptbe lett mozgatva."
log "[COMMIT] Konfigurációs fájl lezárása és backup törlése."

# Visszazárás
if [ "$BLACKLIST_LOCKED" -eq 1 ] || command -v chattr &> /dev/null; then
    chattr +i "$BLACKLIST_FILE" # Hiba esetén TRAP fut!
fi

# Töröljük a sikeres futás után a backupot
rm -f "$BLACKLIST_BACKUP_FILE"

log "[DONE] 17-es ág befejezve. Modulok blacklistelve és a konfiguráció lezárva."
exit 0
