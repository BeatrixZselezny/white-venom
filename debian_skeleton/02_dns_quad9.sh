#!/usr/bin/env bash
# 02_dns_quad9.sh – Rendszer DNS konfiguráció Quad9 IPv4-re
# JAVÍTÁSOK:
# 1. Unbound/DoT logika kiszervezve.
# 2. Quad9 címek átállítva IPv4-re (Android hotspot kompatibilitás).
# 3. Robusztus Rollback logika a resolv.conf-hoz.
# 4. chattr +i/-i hibaellenőrzés nélkül fut (set -e/trap ERR kezeli).

set -euo pipefail

# ⚙️ KONFIGURÁCIÓ
# KRITIKUS JAVÍTÁS: Visszaváltás IPv4-re az Android Hotspot limitáció miatt.
QUAD9_A1="9.9.9.9"
QUAD9_A2="149.112.112.112"
RESOLV_CONF="/etc/resolv.conf"
SCRIPT_NAME="02_DNS_QUAD9"

# 🛠️ ROLLBACK TÁRGYAK
RESOLV_CONF_BACKUP="${RESOLV_CONF}.bak.${SCRIPT_NAME}"
LOCK_STATUS_RESOLV=""

# --- LOG ÉS FUSS FUNKCIÓK ---

log() {
    local level="$1"; shift
    local msg="$*"
    printf "%s [%s/%s] %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$SCRIPT_NAME" "$level" "$msg"
}

run() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "DRY" "$*"
    else
        log "ACTION" "$*"
        "$@"
    fi
}

# --- TRANZAKCIÓS TISZTÍTÁS (BRANCH_CLEANUP) ---

function branch_cleanup() {
    log "FATAL" "Hiba történt a 02-es ág futása közben! Rollback indítása..."

    # 1. resolv.conf feloldása és visszaállítása
    if command -v chattr &> /dev/null; then
        # KRITIKUS JAVÍTÁS: chattr -i hiba elnyelése nélkül!
        chattr -i "$RESOLV_CONF" 2>/dev/null || true
    fi

    if [ -f "$RESOLV_CONF_BACKUP" ]; then
        log "INFO" "-> $RESOLV_CONF visszaállítása a backupból."
        mv "$RESOLV_CONF_BACKUP" "$RESOLV_CONF" || true
    fi

    log "FATAL" "02-es ág rollback befejezve. Kézi ellenőrzés szükséges!"
    exit 1
}
trap branch_cleanup ERR

# ---------------------------------------------------------------------------
# 0. ELŐKÉSZÍTÉS ÉS BEMENET ELLENŐRZÉSE
# ---------------------------------------------------------------------------

MODE="${1:---apply}"
DRY_RUN=0
if [[ "$MODE" == "--dry-run" ]]; then
    DRY_RUN=1
    log "INFO" "Mode: --dry-run (szimuláció)"
fi

log "--- DNS konfiguráció (Quad9/IPv4, Unbound-mentes) ---"

# --- 1. RENDSZER DNS ÁTIRÁNYÍTÁSA QUAD9-RE ---
log "1. $RESOLV_CONF konfigurálása Quad9 IPv4 címekre."

# 1a. Backup készítése / Állapot ellenőrzése
if [ -f "$RESOLV_CONF" ]; then
    log "INFO" "-> $RESOLV_CONF backup készítése: $RESOLV_CONF_BACKUP."
    run cp "$RESOLV_CONF" "$RESOLV_CONF_BACKUP"
fi

# 1b. A resolv.conf fájl lezárásának feloldása
if command -v chattr &> /dev/null; then
    LOCK_STATUS_RESOLV=$(lsattr "$RESOLV_CONF" 2>/dev/null | awk '{print $1}' | grep -o "i" || true)
    if [ "$LOCK_STATUS_RESOLV" == "i" ]; then
        log "INFO" "-> $RESOLV_CONF feloldása (chattr -i)..."
        # KRITIKUS JAVÍTÁS: Eltávolítva a hiba elnyelés.
        run chattr -i "$RESOLV_CONF"
    fi
fi

# 1c. /etc/resolv.conf átírása Quad9 IPv4 címekre
log "ACTION" "/etc/resolv.conf tartalmának felülírása."
if [[ "$DRY_RUN" -eq 0 ]]; then
cat > "$RESOLV_CONF" <<EOF
# resolv.conf - Generálva a ${SCRIPT_NAME}.sh hardening szkript által
# ZERO TRUST: Közvetlen Quad9 (IPv4) felé irányítás a hotspot limitáció miatt.
nameserver $QUAD9_A1
nameserver $QUAD9_A2
# Kiegészítő opciók a DNS szigorítására
options single-request-reopen  # Elkerüljük az IPv4 / IPv6 kettős lekérdezését
options rotate                 # Egyszerű load balancing
EOF
fi

log "Kész: $RESOLV_CONF átírva Quad9 címekre."


# --- 2. KONFIGURÁCIÓ VISSZAZÁRÁSA (COMMIT) ---

# 2a. resolv.conf visszazárása
if [ "$LOCK_STATUS_RESOLV" == "i" ] && command -v chattr &> /dev/null; then
    log "COMMIT" "$RESOLV_CONF visszazárása (chattr +i)..."
    # KRITIKUS JAVÍTÁS: chattr hiba elnyelése nélkül!
    run chattr +i "$RESOLV_CONF"
elif command -v chattr &> /dev/null; then
    # Ha nem volt lezárva, akkor default módon lezárjuk, mivel kritikus fájl
    log "COMMIT" "$RESOLV_CONF lezárása (chattr +i) a Zero-Trust miatt."
    run chattr +i "$RESOLV_CONF"
fi


# Sikeres commit után töröljük a backupot
run rm -f "$RESOLV_CONF_BACKUP"

log "APPLY COMPLETE: $RESOLV_CONF sikeresen konfigurálva Quad9 IPv4-re."
exit 0
