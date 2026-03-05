#!/bin/bash
# 19_stack_canary_enforce.sh - Stack Canary (-fstack-protector-strong) kikényszerítése globálisan

# Zero-Trust/Tranzakcionális beállítások:
set -euo pipefail
LOGFILE="/var/log/stack_canary_enforce.log"
STACK_CANARY_FLAG="-fstack-protector-strong"

MAKE_CONF="/etc/make.conf"
ENV_CONF="/etc/environment"

# Globális log függvényt feltételezünk
log() { echo "$(date +%F' '%T) $*" | tee -a "$LOGFILE"; }

# --- TRANZAKCIÓS TISZTÍTÁS (CLEANBACK) ---
# Rollback: Visszaállítja az eredeti fájlokat hiba esetén, és feloldja a lockot.
function branch_cleanup() {
    log "[CRITICAL ALERT] Hiba történt a 19-es ág futása közben! Megkísérlem a rollbacket..."
    
    # 1. /etc/make.conf visszaállítása
    if [ -f "${MAKE_CONF}.bak.19" ]; then
        log "   -> $MAKE_CONF visszaállítása a backupból."
        mv "${MAKE_CONF}.bak.19" "$MAKE_CONF"
        # Mivel a hiba előtt lezárhattuk, feloldjuk
        if command -v chattr &> /dev/null; then chattr -i "$MAKE_CONF" || true; fi
    fi
    
    # 2. /etc/environment visszaállítása
    if [ -f "${ENV_CONF}.bak.19" ]; then
        log "   -> $ENV_CONF visszaállítása a backupból."
        mv "${ENV_CONF}.bak.19" "$ENV_CONF"
        if command -v chattr &> /dev/null; then chattr -i "$ENV_CONF" || true; fi
    fi
    
    log "[CRITICAL ALERT] 19-es ág rollback befejezve. Kézi ellenőrzés szükséges!"
    exit 1
}
trap branch_cleanup ERR

log "--- 19_stack_canary_enforce: Stack Canary beállítások kikényszerítése ---"

# --- HELPER FUNKCIÓ A FLAG-EK TISZTÍTÁSÁRA ---
# Eltávolítja a régi/gyengébb canary flag-eket és a duplikációkat.
clean_flags() {
    local FLAGS="$1"
    # Eltávolítja a gyengébb opciókat és a -fstack-protector-strong duplikációkat
    echo "$FLAGS" | sed 's/-fstack-protector-all//g' \
                  | sed 's/-fstack-protector[^s][^t]//g' \
                  | tr ' ' '\n' \
                  | grep -vE '^\s*$' \
                  | sort -u \
                  | tr '\n' ' ' \
                  | xargs \
                  | sed "s/$/ $STACK_CANARY_FLAG/" \
                  | xargs | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs
}

# --- 1. CFLAGS/CXXFLAGS beállítása globális build környezethez (/etc/make.conf) ---
log "1. CFLAGS/CXXFLAGS beállítása globális build környezethez ($MAKE_CONF)..."

if [ -f "$MAKE_CONF" ]; then
    log "[ACTION] Backup készítése: $MAKE_CONF"
    cp "$MAKE_CONF" "${MAKE_CONF}.bak.19"
    
    # Feloldjuk a lockot a módosítás idejére
    local MAKE_CONF_LOCKED=0
    if command -v chattr &> /dev/null && lsattr "$MAKE_CONF" 2>/dev/null | grep -q "i"; then
        chattr -i "$MAKE_CONF" # Hiba esetén TRAP fut
        MAKE_CONF_LOCKED=1
    fi

    update_make_conf_flags() {
        local VAR_NAME=$1
        
        # 1. Kinyerjük a régi flag-eket, vagy üres stringet használunk
        if grep -q "^${VAR_NAME}=" "$MAKE_CONF"; then
            OLD_FLAGS=$(grep "^${VAR_NAME}=" "$MAKE_CONF" | cut -d\" -f2)
        else
            OLD_FLAGS=""
        fi
        
        NEW_FLAGS=$(clean_flags "$OLD_FLAGS")
        
        # 2. Beszúrás/Felülírás
        if grep -q "^${VAR_NAME}=" "$MAKE_CONF"; then
            # Lecseréli a meglévő sort
            sed -i "/^${VAR_NAME}=/c\\${VAR_NAME}=\"${NEW_FLAGS}\"" "$MAKE_CONF"
            log "   -> Frissítve: ${VAR_NAME} beállítva \"${NEW_FLAGS}\"."
        else
            # Hozzáadja a fájl végéhez
            echo "${VAR_NAME}=\"${NEW_FLAGS}\"" >> "$MAKE_CONF"
            log "   -> Hozzáadva: ${VAR_NAME} új sorral: \"${NEW_FLAGS}\"."
        fi
    }
    
    update_make_conf_flags "CFLAGS"
    update_make_conf_flags "CXXFLAGS"
    
    # Visszazárás (COMMIT)
    if [ "$MAKE_CONF_LOCKED" -eq 1 ] || command -v chattr &> /dev/null; then
        log "[COMMIT] $MAKE_CONF lezárása (chattr +i)."
        chattr +i "$MAKE_CONF" # Hiba esetén TRAP fut
    fi
    
    # Sikeres COMMIT után töröljük a backupot
    rm -f "${MAKE_CONF}.bak.19"

else
    log "[FIGYELEM] A $MAKE_CONF fájl nem található. Kihagyás."
fi

# --- 2. Globális környezeti változók beállítása (/etc/environment) ---
log "2. Globális környezeti változók ($ENV_CONF) beállítása..."

# Backup a rollbackhez
log "[ACTION] Backup készítése: $ENV_CONF"
cp "$ENV_CONF" "${ENV_CONF}.bak.19"

# Feloldjuk a lockot a módosítás idejére
local ENV_CONF_LOCKED=0
if command -v chattr &> /dev/null && lsattr "$ENV_CONF" 2>/dev/null | grep -q "i"; then
    chattr -i "$ENV_CONF"
    ENV_CONF_LOCKED=1
fi

# Készítünk egy ideiglenes fájlt a frissített tartalom tárolására.
TEMP_ENV=$(mktemp)

update_env_conf_flags() {
    local VAR_NAME=$1
    local INPUT_FILE=$2
    
    # 1. Kinyerjük a régi flag-eket
    if grep -q "^${VAR_NAME}=" "$ENV_CONF"; then
        OLD_FLAGS=$(grep "^${VAR_NAME}=" "$ENV_CONF" | cut -d\" -f2)
    else
        OLD_FLAGS=""
    fi
    
    NEW_FLAGS=$(clean_flags "$OLD_FLAGS")
    
    # 2. Eltávolítjuk a régi sort, ha létezett
    grep -v "^${VAR_NAME}=" "$INPUT_FILE" > "$TEMP_ENV.tmp"
    
    # 3. Hozzáadjuk az új, tiszta sort
    echo "${VAR_NAME}=\"${NEW_FLAGS}\"" >> "$TEMP_ENV.tmp"
    
    mv "$TEMP_ENV.tmp" "$INPUT_FILE"
    log "   -> Beállítva: ${VAR_NAME} a(z) $ENV_CONF fájlban: \"${NEW_FLAGS}\"."
}

# Inicializáljuk a TEMP_ENV-t a meglévő /etc/environment tartalmával
cp "$ENV_CONF" "$TEMP_ENV"

# Frissítjük a CFLAGS és CXXFLAGS változókat a TEMP_ENV fájlban
update_env_conf_flags "CFLAGS" "$TEMP_ENV"
update_env_conf_flags "CXXFLAGS" "$TEMP_ENV"

# Felülírjuk az /etc/environment fájlt a frissített tartalommal
mv "$TEMP_ENV" "$ENV_CONF"
rm -f "$TEMP_ENV" 2> /dev/null

# Visszazárás (COMMIT)
if [ "$ENV_CONF_LOCKED" -eq 1 ] || command -v chattr &> /dev/null; then
    log "[COMMIT] $ENV_CONF lezárása (chattr +i)."
    chattr +i "$ENV_CONF"
fi

# Sikeres COMMIT után töröljük a backupot
rm -f "${ENV_CONF}.bak.19"

log "[DONE] Stack Canary opciók kikényszerítve az összes globális build konfigurációban."
log "--- 19_stack_canary_enforce Befejezve ---"
exit 0
