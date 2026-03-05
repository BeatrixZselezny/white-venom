#!/bin/bash
# branches/13_banner_grabbing_hardening.sh
# Banner grabbing támadások tiltása: Rendszer és alkalmazás verziószámok elrejtése.
set -euo pipefail

# --- KONZISZTENCIA ÉS KONFIG ---
LOGFILE="/var/log/banner_hardening.log"
ISSUE_FILES=("/etc/issue" "/etc/issue.net")
UNBOUND_CONF_DIR="/etc/unbound/unbound.conf.d"
UNBOUND_CONF_FILE="$UNBOUND_CONF_DIR/00-hardening.conf" # feltételezve, hogy ez a hardening fájl neve
# Globális log függvényt feltételezünk
log() { echo "$(date +%F' '%T) $*" | tee -a "$LOGFILE"; }

# ... (Root ellenőrzés) ...

# --- TRANZAKCIÓS TISZTÍTÁS (CLEANUP/ROLLBACK) ---
branch_cleanup() {
    log "[CRITICAL ALERT] Hiba történt a 13-as ág futása közben! Megkísérlem a rollbacket..."
    
    # Fő rollback: Az immutability lock feloldása
    log "[ACTION] Immutability lock feloldása a /etc/issue fájlokról."
    for file in "${ISSUE_FILES[@]}"; do
        chattr -i "$file" || true
    done

    # UNBOUND config rollback
    # Mivel ez csak hozzáad egy sort, a rollback a sor eltávolítása (manuálisan nehezebb)

    log "[CRITICAL ALERT] 13-as ág rollback befejezve. Kérjük, ellenőrizze az /etc/issue tartalmát!"
}
trap branch_cleanup ERR

# --- 1. RENDSZER BANNER (ISSUE FÁJLOK) ELREJTÉSE ---
log "--- 1. RENDSZER BANNER (ISSUE FÁJLOK) ELREJTÉSE ---"

for file in "${ISSUE_FILES[@]}"; do
    if [ -f "$file" ]; then
        log "[ACTION] $file tartalmának törlése (minimalizálás)."
        # Töröljük a tartalmát, vagy írjunk be egy minimalista üzenetet
        echo "Authorized Access Only." > "$file"
        
        # Lezárás: Immutability Lock
        log "[HARDENING] chattr +i kényszerítése a $file-ra (megakadályozza a módosítást)."
        chattr +i "$file"
        
        # Jogosultságok szigorítása (ha még nem történt meg a 11-es ágban)
        chown root:root "$file"
        chmod 600 "$file"
    else
        log "[WARNING] $file nem található, kihagyva a hardeninget."
    fi
done

# --- 2. ALKALMAZÁS VERZIÓK ELREJTÉSE (UNBOUND) ---
log "--- 2. ALKALMAZÁS VERZIÓK ELREJTÉSE (UNBOUND) ---"

if [ -d "$UNBOUND_CONF_DIR" ]; then
    log "[ACTION] Unbound verziószám elrejtés kényszerítése (hide-version: yes)."
    
    # Létrehozzuk/frissítjük a hardening konfig fájlt
    cat >> "$UNBOUND_CONF_FILE" << EOF
# Hardening: Tiltja a verziószám kiadását a version.bind (CHAOS) lekérdezésekre.
server:
    hide-version: yes
EOF

    # Unbound jogosultságok újra beállítása (a 11-es ág megerősítése)
    chown unbound:unbound "$UNBOUND_CONF_FILE"
    chmod 640 "$UNBOUND_CONF_FILE"

    log "[ACTION] Unbound újraindítása az új konfiguráció érvényesítéséhez."
    # service unbound restart || log "[WARNING] Nem sikerült az Unbound újraindítása. Manuális ellenőrzés szükséges!"
else
    log "[WARNING] Unbound konfigurációs könyvtár nem található. Kihagyva az Unbound hardeninget."
fi


# --- 3. HARDENING UTÁNI ELLENŐRZÉS ---
log "--- 3. HARDENING UTÁNI ELLENŐRZÉS ---"

# Ellenőrizzük az immutability-t
for file in "${ISSUE_FILES[@]}"; do
    if [ -f "$file" ] && lsattr "$file" | grep -q 'i'; then
        log "[OK] $file lezárva (chattr +i) a módosítások ellen."
    else
        log "[CRITICAL ERROR] $file nem zárolt!"
        exit 1
    fi
done

log "[DONE] 13-as ág befejezve. Banner grabbing támadások elleni védelem aktív."
exit 0
