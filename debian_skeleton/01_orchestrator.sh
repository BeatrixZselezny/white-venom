#!/usr/bin/env bash
# 01_orchestrator.sh - Zero Trust Hardening Orchestrator
# Kezeli a futtatási fázisokat: --dry-run, --apply, --audit, --snapshot

set -euo pipefail
IFS=$'\n\t'

# --- KONFIGURÁCIÓ ---
LOGDIR="/var/log/skell"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
# Megkeresi az összes számozott szkriptet (00_install.sh-tól felfelé)
# A szkript maga (01_orchestrator.sh) ki lesz zárva a futtatásból.
# A find sorba rendezi a fájlokat: 00, 02, 03, 27, 28, 29, stb.
ALL_SCRIPTS=$(find . -maxdepth 1 -type f -name '[0-9][0-9]_*.sh' | sort)

# --- SEGÉDFÜGGVÉNYEK ---
mkdir -p "$LOGDIR" || true
log() { echo "$(date +%F' '%T) [01_ORCHESTRATOR] $*" | tee -a "$LOGDIR/01_install_$TIMESTAMP.log"; }

on_err() {
  local rc=$?
  log "KRITIKUS HIBA: A futtatás megszakadt (exit $rc). Lásd a logot a hibás szkriptnél."
  exit $rc
}
trap on_err ERR

usage() {
    echo "Használat: $0 [--dry-run | --apply | --audit | --snapshot]"
    echo ""
    echo "FÁZISOK:"
    echo "  --dry-run:  Futásszimuláció: Minden szkript kiírja, mit tenne (írási művelet nélkül)."
    echo "  --apply:    Alkalmazás: Elvégzi a tényleges konfigurációs módosításokat (00-27)."
    echo "  --audit:    Ellenőrzés: Csak a 28_reconciliation_audit.sh futtatása."
    echo "  --snapshot: Véglegesítés: Csak a 29_system_baseline_snapshot.sh futtatása (hash rögzítés)."
    exit 1
}

# ---------------------------
# FŐ LOGIKA
# ---------------------------
if [ $# -eq 0 ]; then
    usage
fi

MODE=""
case "$1" in
    --dry-run)  MODE="--dry-run"; log "START: DRY-RUN SZIMULÁCIÓ"; ;;
    --apply)    MODE="--apply"; log "START: KONFIGURÁCIÓ ALKALMAZÁSA (APPLY)"; ;;
    --audit)    MODE="--audit"; log "START: AUDIT FÁZIS"; ;;
    --snapshot) MODE="--snapshot"; log "START: BASELINE SNAPSHOT FÁZIS"; ;;
    *)          usage; ;;
esac


# A szekvenciális végrehajtó
run_scripts() {
    local script_mode=$1
    local total_scripts=$(echo "$ALL_SCRIPTS" | wc -l)
    local current_count=0
    
    for script_path in $ALL_SCRIPTS; do
        script_name=$(basename "$script_path")

        # Exkludáljuk önmagunkat
        if [ "$script_name" == "01_orchestrator.sh" ]; then
            continue
        fi

        current_count=$((current_count + 1))
        
        # 1. Speciális fázisok kezelése (--audit, --snapshot)
        if [ "$MODE" == "--audit" ]; then
            if [ "$script_name" != "28_reconciliation_audit.sh" ]; then
                continue # Csak az audit szkript futhat
            fi
        fi
        
        if [ "$MODE" == "--snapshot" ]; then
            if [ "$script_name" != "29_system_baseline_snapshot.sh" ]; then
                continue # Csak a snapshot szkript futhat
            fi
        fi
        
        # 2. --dry-run és --apply mód (Minden szkript 28-ig)
        if [ "$MODE" == "--dry-run" ] || [ "$MODE" == "--apply" ]; then
            # Kizárjuk a 28 és 29-es audit/snapshot szkripteket
            if [[ "$script_name" == "28_reconciliation_audit.sh" ]] || [[ "$script_name" == "29_system_baseline_snapshot.sh" ]]; then
                continue 
            fi
        fi
        
        # FUTTATÁS
        log "FUTTATÁS [$current_count/$total_scripts]: $script_name $script_mode"
        
        # Átadjuk az argumentumot a szkriptnek
        "$script_path" "$script_mode" || {
            log "KRITIKUS HIBA: $script_name hibával zárult ($?). Megszakítás."
            return 1
        }
    done
}

# --- FUTTATÁS ---
run_scripts "$MODE"

log "VÉGE: A FÁZIS ($MODE) befejeződött."
exit 0