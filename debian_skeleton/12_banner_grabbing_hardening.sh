#!/usr/bin/env bash
# branches/13_banner_grabbing_hardening.sh
# Banner grabbing támadások tiltása: Rendszer és alkalmazás verziószámok elrejtése.
set -euo pipefail

# --- KONZISZTENCIA ÉS KONFIG ---
LOGFILE="/var/log/skell/13_banner_hardening.log" # Log útvonal egységesítése
ISSUE_FILES=("/etc/issue" "/etc/issue.net")
UNBOUND_CONF_DIR="/etc/unbound/unbound.conf.d"
# JAVÍTÁS 2: Fájlnév módosítása a sorrendi konzisztencia érdekében
UNBOUND_CONF_FILE="$UNBOUND_CONF_DIR/09-hide-version.conf"
# ... (Root ellenőrzés) ...
# ... (log függvény definíciója - feltételezve, hogy létezik)

# --- TRANZAKCIÓS TISZTÍTÁS (CLEANUP/ROLLBACK) ---
branch_cleanup() {
    log "[CRITICAL ALERT] Hiba történt a 13-as ág futása közben! Megkísérlem a rollbacket..."
    
    # Fő rollback: Az issue fájlok immutability lock feloldása
    log "[ACTION] Immutability lock feloldása az issue fájlokról."
    for file in "${ISSUE_FILES[@]}"; do
        chattr -i "$file" 2>/dev/null || true
    done

    # JAVÍTÁS 3: UNBOUND config rollback: Ha a fájl létezik, töröljük, mivel ez a szkript hozta létre.
    if [ -f "$UNBOUND_CONF_FILE" ]; then
        log "[ACTION] Unbound konfigurációs fájl törlése: $UNBOUND_CONF_FILE"
        rm -f "$UNBOUND_CONF_FILE" || true
    fi

    log "[CRITICAL ALERT] 13-as ág rollback befejezve. Manuális ellenőrzés szükséges!"
}
trap branch_cleanup ERR

# --- 1. RENDSZER BANNER (ISSUE FÁJLOK) ELREJTÉSE ---
log "--- 1. RENDSZER BANNER (ISSUE FÁJLOK) ELREJTÉSE ---"

for file in "${ISSUE_FILES[@]}"; do
    if [ -f "$file" ]; then
        # chattr feloldása, hogy írni tudjunk bele (rollback nélkül is szükséges!)
        chattr -i "$file" 2>/dev/null || true 
        log "[ACTION] $file tartalmának minimalizálása."
        echo "Authorized Access Only." > "$file"
        
        # Jogosultságok szigorítása
        chown root:root "$file"
        chmod 600 "$file"
        
        # Lezárás: Immutability Lock
        log "[HARDENING] chattr +i kényszerítése a $file-ra."
        chattr +i "$file"
    else
        log "[WARNING] $file nem található, kihagyva a hardeninget."
    fi
done

# --- 2. ALKALMAZÁS VERZIÓK ELREJTÉSE (UNBOUND) ---
log "--- 2. ALKALMAZÁS VERZIÓK ELREJTÉSE (UNBOUND) ---"

if [ -d "$UNBOUND_CONF_DIR" ]; then
    log "[ACTION] Unbound verziószám elrejtés kényszerítése (hide-version: yes) a $UNBOUND_CONF_FILE fájlban."
    
    # Létrehozzuk/frissítjük a hardening konfig fájlt
    cat > "$UNBOUND_CONF_FILE" << EOF
# Hardening: Tiltja a verziószám kiadását a version.bind (CHAOS) lekérdezésekre.
server:
    hide-version: yes
EOF

    # JAVÍTÁS 5: Jogosultság beállítása: root:root és 600/644
    chown root:root "$UNBOUND_CONF_FILE"
    chmod 600 "$UNBOUND_CONF_FILE"

    # JAVÍTÁS 1: Kritikus hiba: Az újraindításnak meg kell szakítania a szkriptet hiba esetén!
    log "[ACTION] Unbound újraindítása az új konfiguráció érvényesítéséhez."
    service unbound restart || { log "[FATAL ERROR] Unbound újraindítás sikertelen! A szkript leáll."; exit 1; }
else
    log "[WARNING] Unbound konfigurációs könyvtár nem található. Kihagyva az Unbound hardeninget."
fi


# --- 3. HARDENING UTÁNI ELLENŐRZÉS ---
log "--- 3. HARDENING UTÁNI ELLENŐRZÉS ---"

# Ellenőrizzük az immutability-t
for file in "${ISSUE_FILES[@]}"; do
    if [ -f "$file" ]; then
        if lsattr "$file" | grep -q 'i'; then
            log "[OK] $file lezárva (chattr +i) a módosítások ellen."
        else
            log "[CRITICAL ERROR] $file nem zárolt! chattr +i Hiba!"
            exit 1
        fi
    fi
done

log "[DONE] 13-as ág befejezve. Banner grabbing támadások elleni védelem aktív."
exit 0
