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
# --- SCRIPT LIST BETÖLTÉSE ---
SCRIPT_LIST_FILE="./scripts/scripts.list"

if [[ ! -f "$SCRIPT_LIST_FILE" ]]; then
    log "HIBA: scripts.list nem található: $SCRIPT_LIST_FILE"
    exit 1
fi

readarray -t SCRIPT_ORDER < "$SCRIPT_LIST_FILE"

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
    local mode="$1"
    local count=0
    local total="${#SCRIPT_ORDER[@]}"

    for path in "${SCRIPT_ORDER[@]}"; do
        local name=$(basename "$path")

        case "$mode" in
            --audit)
                [[ "$name" != "28_reconciliation_audit.sh" ]] && continue
                ;;
            --snapshot)
                [[ "$name" != "29_system_baseline_snapshot.sh" ]] && continue
                ;;
            --dry-run|--apply)
                [[ "$name" == "28_reconciliation_audit.sh" || "$name" == "29_system_baseline_snapshot.sh" ]] && continue
                ;;
        esac

        count=$((count + 1))
        log "FUTTATÁS [$count/$total]: $name $mode"
        "$path" "$mode"
    done
}


# --- FUTTATÁS ---
run_scripts "$MODE"

log "VÉGE: A FÁZIS ($MODE) befejeződött."
exit 0

# --- hw_vuln_inject.sh integrálás ---
HW_VULN_SCRIPT="./scripts/hw_vuln_inject.sh"

if [[ "$1" == "--dry-run" ]]; then
    log "Dry-run módban futtatva. A hw_vuln_inject.sh szkript nem lesz végrehajtva, csak naplózva."
    echo "A következő műveletek nem kerülnek végrehajtásra:"
    echo "Hozzáadott mitigációs paraméterek a kernelhez: $KERNEL_OPTS $SMT_OPTS"
else
    # Futtatjuk a hw_vuln_inject.sh szkriptet
    if [[ -f "$HW_VULN_SCRIPT" ]]; then
        log "Futtatjuk a hw_vuln_inject.sh szkriptet."
        bash "$HW_VULN_SCRIPT"
    else
        log "HIBA: hw_vuln_inject.sh szkript nem található!"
        exit 1
    fi
fi
