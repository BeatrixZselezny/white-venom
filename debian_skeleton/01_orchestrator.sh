#!/usr/bin/env bash
# 01_orchestrator.sh – White Venom / SKELL Orchestrator
# Fázisvezérlés: --dry-run | --apply | --restore | --audit | --snapshot

set -euo pipefail

SCRIPT_NAME="01_ORCHESTRATOR"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/whitevenom"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/${TIMESTAMP}_01_orchestrator.log"

CURRENT_MODULE="(none)"

log() {
    local level="$1"; shift
    local msg="$*"
    printf "%s [%s/%s] %s\n" \
        "$(date +"%Y-%m-%d %H:%M:%S")" \
        "$SCRIPT_NAME" "$level" "$msg"
}

usage() {
    cat <<EOF
Használat: $0 [--dry-run | --apply | --restore | --audit | --snapshot]

FÁZISOK:
  --dry-run   Futásszimuláció: a modulok kiírják, mit tennének (írás nélkül).
  --apply     Alkalmazás: 00–25 modulok futtatása, majd 90_release_locks.sh (ha van).
  --restore   Visszavonás: 00–25 modulok futtatása fordított sorrendben (25→00), majd 90 (ha van).
  --audit     Audit mód: csak 28–29 tartomány futtatása (ha létezik).
  --snapshot  Snapshot mód: keret, nincs implementált backend.

EOF
}

on_err() {
    local ec=$?
    log "FATAL" "Hiba (exit=$ec). Modul: $CURRENT_MODULE. Parancs: ${BASH_COMMAND}"
    exit "$ec"
}
trap on_err ERR

# --- MODE PARSE -------------------------------------------------------------

MODE="${1:-}"

case "$MODE" in
    --dry-run|--apply|--restore|--audit|--snapshot)
        ;;
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

# --- LOGDIR ---------------------------------------------------------------

mkdir -p "$LOG_DIR"
chmod 700 "$LOG_DIR"

# minden stdout/stderr menjen file + konzolra
exec > >(tee -a "$LOG_FILE") 2>&1

log "INFO" "Indul az orchestrator. Mód: $MODE"
log "INFO" "SCRIPT_DIR: $SCRIPT_DIR"
log "INFO" "LOG_FILE:   $LOG_FILE"

# --- MODUL DETEKTÁLÁS -------------------------------------------------------

get_modules_sorted() {
    # Stabil, glob-alapú gyűjtés + sort -V (verzió-szerű rendezés)
    shopt -s nullglob
    local paths=( "$SCRIPT_DIR"/[0-9][0-9]_*.sh )
    shopt -u nullglob

    local filtered=()
    local p b
    for p in "${paths[@]}"; do
        b="$(basename "$p")"
        [[ "$b" == "01_orchestrator.sh" ]] && continue
        filtered+=( "$p" )
    done

    # sort -V: 02_, 03_, 10_ stb. jól rendezve
    if ((${#filtered[@]} > 0)); then
        printf "%s\n" "${filtered[@]}" | sort -V
    fi
}

build_plan() {
    local mode="$1"
    local all_modules=()
    mapfile -t all_modules < <(get_modules_sorted)

    local plan=()
    local p b prefix num
    for p in "${all_modules[@]}"; do
        b="$(basename "$p")"
        prefix="${b%%_*}"
        num=$((10#$prefix))

        case "$mode" in
            --dry-run|--apply|--restore)
                [[ "$num" -ge 0 && "$num" -le 25 ]] && plan+=( "$p" )
                ;;
            --audit)
                [[ "$num" -ge 28 && "$num" -le 29 ]] && plan+=( "$p" )
                ;;
            --snapshot)
                ;;
        esac
    done

    printf "%s\n" "${plan[@]}"
}

run_module() {
    local mode="$1"
    local module_path="$2"
    local module_name
    module_name="$(basename "$module_path")"

    CURRENT_MODULE="$module_name"
    log "INFO" "Futtatás ($mode): $module_name"
    bash "$module_path" "$mode"
    CURRENT_MODULE="(none)"
}

run_pipeline() {
    local mode="$1"
    local plan=()
    mapfile -t plan < <(build_plan "$mode")

    local total=${#plan[@]}
    log "INFO" "Futtatási terv: $total modul."

    if [[ "$total" -eq 0 ]]; then
        case "$mode" in
            --audit)
                log "WARN" "Audit mód, de nincs 28–29 modul. (Nincs teendő.)"
                ;;
            --snapshot)
                log "WARN" "Snapshot mód: nincs implementált backend."
                ;;
            *)
                log "WARN" "Nincs futtatható modul a kiválasztott módban."
                ;;
        esac
        return 0
    fi

    local i

    case "$mode" in
        --restore)
            # fordított sorrend: 25→00, NET-ben így 04→03 automatikusan helyes lesz
            for (( i=total-1; i>=0; i-- )); do
                log "INFO" "--- FUTTATÁS (restore) $((total-i))/$total: $(basename "${plan[$i]}") ---"
                run_module "$mode" "${plan[$i]}"
            done
            ;;
        --dry-run|--apply|--audit)
            for (( i=0; i<total; i++ )); do
                log "INFO" "--- FUTTATÁS $((i+1))/$total: $(basename "${plan[$i]}") ---"
                run_module "$mode" "${plan[$i]}"
            done
            ;;
        --snapshot)
            log "WARN" "Snapshot mód: jelenleg csak keret."
            ;;
    esac

    # 90_release_locks.sh kezelése (ha létezik)
    if [[ -f "$SCRIPT_DIR/90_release_locks.sh" ]]; then
        log "INFO" "--- VÉGZŐ FÁZIS: 90_release_locks.sh ($mode) ---"
        CURRENT_MODULE="90_release_locks.sh"
        bash "$SCRIPT_DIR/90_release_locks.sh" "$mode"
        CURRENT_MODULE="(none)"
    else
        log "INFO" "90_release_locks.sh nem található – nincs külön lock-release fázis."
    fi
}

# --- FUTTATÁS ---------------------------------------------------------------

run_pipeline "$MODE"

log "INFO" "Orchestrator lefutott. Mód: $MODE – VÉGE."
exit 0

