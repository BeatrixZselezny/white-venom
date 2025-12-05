#!/usr/bin/env bash
# 01_orchestrator.sh – White Venom / SKELL Orchestrator
# Fázisvezérlés: --dry-run | --apply | --audit | --snapshot
#
# JAVÍTÁSOK:
#   - Fájllista kezelése ls alapú listával (nem find).
#   - Számláló logika beépítése a futtatásba.
#   - Redundáns számozás alapú szűrés eltávolítása a run_module funkcióból.

set -euo pipefail

SCRIPT_NAME="01_ORCHESTRATOR"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/whitevenom"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

# A Zero-Trust logikához a log könyvtárnak már léteznie kell (00_install.sh felelőssége)
# A hiba elnyelést eltávolítjuk a chmod-ról (ha nem létezik, FATAL hiba jön)
mkdir -p "$LOG_DIR"
chmod 700 "$LOG_DIR"

log() {
    local level="$1"; shift
    local msg="$*"
    printf "%s [%s/%s] %s\n" \
        "$(date +"%Y-%m-%d %H:%M:%S")" \
        "$SCRIPT_NAME" "$level" "$msg"
}

usage() {
    cat <<EOF
Használat: $0 [--dry-run | --apply | --audit | --snapshot]

FÁZISOK:
  --dry-run   Futásszimuláció: Minden modul kiírja, mit tenne (írás nélkül).
  --apply     Alkalmazás: 00–25 modulok tényleges futtatása, majd 90_release_locks.sh (ha van).
  --audit     Audit mód: csak audit jellegű modul(ok) futtatása (pl. 28_reconciliation_audit.sh, ha létezik).
  --snapshot  Snapshot mód: jelenleg csak keret, nem végez műveletet.

EOF
}

# --- MODE PARSE -------------------------------------------------------------

MODE="${1:-}"

case "$MODE" in
    --dry-run|--apply|--audit|--snapshot)
        ;; # OK
    ""|"-h"|"--help")
        usage
        exit 0
        ;;
    *)
        log "ERROR" "Ismeretlen mód: $MODE"
        usage
        exit 1
        ;;
esac

# --- ROOT CHECK -------------------------------------------------------------

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log "FATAL" "Root jogosultság szükséges az orchestrator futtatásához."
    exit 1
fi

log "INFO" "Indul az orchestrator. Mód: $MODE"

# --- SEGÉDFÜGGVÉNYEK --------------------------------------------------------

# 🛠️ JAVÍTÁS: ls alapú lista, kizárva magát az orchestratort
get_modules() {
    # 00-99 közötti számozott fájlok gyűjtése, rendezve, KIVÉVE a saját magát
    # xargs és basename használata a tisztább fájlnév kinyeréséhez
    ls -1 "$SCRIPT_DIR"/[0-9][0-9]_*.sh | grep -v "01_orchestrator.sh" | xargs -n 1 basename
}

# 🛠️ JAVÍTÁS: Egyszerűsített modul futtatás – a szűrést a run_pipeline végzi
run_module() {
    local mode="$1"
    local module="$2"

    log "INFO" "Futtatás ($mode): $module"
    # A set -e és a trap ERR a futtatott szkriptekben (pl. 00_install.sh) biztosítja a hibakezelést.
    bash "$SCRIPT_DIR/$module" "$mode"
}

run_pipeline() {
    local mode="$1"

    # A modulok listáját tömbbe olvassuk be a biztonságos iterációhoz
    local module_array
    readarray -t module_array <<< "$(get_modules)"

    local total_scripts=${#module_array[@]}
    local current_count=0

    log "INFO" "Detektált modulok ($total_scripts db):"
    for m in "${module_array[@]}"; do
        log "INFO" "  - $m"
    done

    case "$mode" in
        --dry-run|--apply)
            # 00–25 tartomány futtatása
            for mod in "${module_array[@]}"; do
                local prefix="${mod%%_*}"
                local num=$((10#$prefix))

                # Futtatási szűrés a 00-25 tartományra
                if [[ "$num" -ge 0 && "$num" -le 25 ]]; then
                    current_count=$((current_count + 1))
                    log "INFO" "--- FUTTATÁS ($current_count/$total_scripts): $mod ---"
                    run_module "$mode" "$mod"
                elif [[ "$num" -eq 90 ]]; then
                    # Lock release modul a végén fut.
                    :
                fi
            done

            # 90_release_locks.sh kezelése
            if [[ -f "$SCRIPT_DIR/90_release_locks.sh" ]]; then
                # Számláló nem szükséges itt, mert ez egy külön fázis
                log "INFO" "--- VÉGZŐ FÁZIS: 90_release_locks.sh ---"
                bash "$SCRIPT_DIR/90_release_locks.sh" "$mode"
            else
                log "INFO" "90_release_locks.sh nem található – nincs külön lock-release fázis."
            fi
            ;;

        --audit)
            # Audit mód: csak 28–29 tartomány
            local found_audit=0
            for mod in "${module_array[@]}"; do
                local prefix="${mod%%_*}"
                local num=$((10#$prefix))

                if [[ "$num" -ge 28 && "$num" -le 29 ]]; then
                    found_audit=1
                    current_count=$((current_count + 1))
                    log "INFO" "--- AUDIT FUTTATÁS ($current_count/$total_scripts): $mod ---"
                    run_module "$mode" "$mod"
                fi
            done

            if [[ "$found_audit" -eq 0 ]]; then
                log "WARN" "Audit mód kérése, de nem található 28xx audit modul. (Nincs teendő.)"
            fi
            ;;

        --snapshot)
            log "WARN" "Snapshot mód jelenleg csak keret – nincs implementált snapshot backend."
            log "WARN" "Ha szükséges, itt lehet integrálni btrfs/lvm/zfs snapshot modulokat (tools/ alól)."
            ;;
    esac
}

# --- FUTTATÁS ---------------------------------------------------------------

run_pipeline "$MODE"

log "INFO" "Orchestrator lefutott. Mód: $MODE – VÉGE."
exit 0
