#!/usr/bin/env bash
# 00_install.sh – White Venom / SKELL baseline bootstrap
# Fázisok:
#   0.00 – Environment sterilization
#   0.15 – Network + kernel/fs lockdown (sysctl)
#   1.0  – GRUB env tool + kernelopts baseline
#   1.5  – [DISABLED] Zero-Trust: Systemd Csomagrögzítés (APT Pinning)  # handled by 05 hook
#   2.0  – APT toolchain + memguard deps + security baseline
#   3.0  – ldconfig sanity
#   4.0  – Baseline dirs
#   5.0  – Canary

set -euo pipefail

# ---------------------------------------------------------------------------
# GLOBAL KONFIGURÁCIÓK ÉS ROLLBACK CÉLOK
# ---------------------------------------------------------------------------

# 🛠️ A szkript által létrehozott kritikus fájlok, amiket rollbackelni kell
NET_SYSCTL_FILE="/etc/sysctl.d/00_whitevenom_bootstrap.conf"
# SYSTEMD_PREF_FILE="/etc/apt/preferences.d/99systemd-noinstall"
# NOTE: Systemd pinning is disabled here; enforcement is handled by 05_dpkg_apt_hardening (APT pre-install hook).
# ---------------------------------------------------------------------------
# LOG FUNKCIÓ
# ---------------------------------------------------------------------------

SCRIPT_NAME="00_INSTALL"

log() {
    local level="$1"; shift
    local msg="$*"
    printf "%s [%s] %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$SCRIPT_NAME/$level" "$msg"
}

# ---------------------------------------------------------------------------
# 🛡️ JAVÍTÁS: ROLLBACK FÜGGVÉNY ÉS TRAP ERR
# ---------------------------------------------------------------------------
branch_cleanup() {
    log "FATAL" "Hiba történt a 00_install.sh futása közben! Rollback indítása..."
# 
#     # 1.5: Systemd Pinning fájl törlése
#     if [ -f "$SYSTEMD_PREF_FILE" ]; then
#         chattr -i "$SYSTEMD_PREF_FILE" 2>/dev/null || true
#         run rm -f "$SYSTEMD_PREF_FILE"
#         log "INFO" "Rollback: $SYSTEMD_PREF_FILE törölve."
#     fi
#     # 0.15: Sysctl fájl törlése
    if [ -f "$NET_SYSCTL_FILE" ]; then
        chattr -i "$NET_SYSCTL_FILE" 2>/dev/null || true
        run rm -f "$NET_SYSCTL_FILE"
        log "INFO" "Rollback: $NET_SYSCTL_FILE törölve."
    fi

    log "FATAL" "A szkript futása megszakadt."
    exit 1
}

# Trap beállítása: minden nem nulla visszatérési kód esetén (set -e miatt) lefut a branch_cleanup
trap branch_cleanup ERR

# ---------------------------------------------------------------------------
# 0.00 – Environment sterilization (prevent env-based root compromise)
# ---------------------------------------------------------------------------

# Fix PATH – no user paths, no injection
export PATH="/usr/sbin:/usr/bin:/sbin:/bin"

# Reset IFS to safe defaults
export IFS=$' \t\n'

# Drop dangerous LD_* vectors
unset LD_PRELOAD
unset LD_LIBRARY_PATH
unset LD_AUDIT
unset LD_DEBUG
unset LD_DEBUG_OUTPUT
unset LD_RUN_PATH

# Drop Python/Ruby/Perl path hijacks
unset PYTHONPATH
unset PYTHONHOME
unset RUBYLIB
unset PERL5LIB
unset PERLLIB
unset PERL5OPT

# Drop Go/Node environment poisoning
unset GOPATH
unset GOMODCACHE
unset NODE_PATH

# Drop Git/SVN injection vectors
unset GIT_CONFIG
unset GIT_CONFIG_GLOBAL
unset GIT_CONFIG_SYSTEM

# Remove exported bash functions (BASH_FUNC_*)
for var in $(env | grep -E '^BASH_FUNC_.*%%=' | cut -d= -f1); do
    unset "$var"
done

# Prevent locale / format-string trükkök
export LANG=C
export LC_ALL=C

# ---------------------------------------------------------------------------
# 0.0 – Root check
# ---------------------------------------------------------------------------
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log "FATAL" "Root required."
    exit 1
fi

# ---------------------------------------------------------------------------
# 0.1 – Mode parsing
# ---------------------------------------------------------------------------
MODE="${1:---apply}"

case "$MODE" in
    --apply)    DRY_RUN=0 ;;
    --dry-run) DRY_RUN=1 ;;
    *)
        log "FATAL" "Unknown mode: $MODE"
        exit 1
        ;;
esac

run() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "DRY" "$*"
    else
        log "ACTION" "$*"
        "$@"
    fi
}

log "INFO" "Mode: $MODE"

# ---------------------------------------------------------------------------
# 0.17 – JAVÍTÁS: Unwanted services immediate disable (exim4 - Systemd-free)
# ---------------------------------------------------------------------------
log "INFO" "Disabling unwanted services (exim4 - Systemd-free)..."

# 📧 Exim4 azonnali leállítása. /etc/init.d közvetlen hívása SysVinit módon
/etc/init.d/exim4 stop 2>/dev/null || log "WARN" "exim4 stop failed (likely not installed)"

# A futási szintekről való eltávolítás, hogy ne induljon el a következő bootoláskor.
run update-rc.d exim4 remove 2>/dev/null || log "WARN" "exim4 disable failed (likely not installed/configured)"

# ---------------------------------------------------------------------------
# 0.15 – Bootstrap Network + Kernel/FS Lockdown
# ---------------------------------------------------------------------------
log "INFO" "Bootstrap network + kernel/fs lockdown..."


if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY" "Would write $NET_SYSCTL_FILE with IPv4 + fs + kernel lockdown sysctls"
    log "DRY" "Would run: sysctl --system"
else
    # Symlink védelem: ne tudjon /etc/passwd stb.-re mutatni
    if [[ -e "$NET_SYSCTL_FILE" && -L "$NET_SYSCTL_FILE" ]]; then
        log "FATAL" "Sysctl target is symlink: $NET_SYSCTL_FILE"
        exit 1
    fi

    cat > "$NET_SYSCTL_FILE" << 'EOF'
# White Venom – Bootstrap IPv4 + kernel/fs hardening lockdown
# ... (sysctl beállítások) ...
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.secure_redirects = 1
net.ipv4.conf.default.secure_redirects = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_local = 0
net.ipv4.conf.default.accept_local = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.shared_media = 0
net.ipv4.conf.default.shared_media = 0
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
fs.protected_fifos = 1
fs.protected_regular = 1
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 1
kernel.unprivileged_bpf_disabled = 1
EOF

    run sysctl --system
fi

# ---------------------------------------------------------------------------
# 0.3 – SKELL environment (optional)
# ---------------------------------------------------------------------------
SKELL_ENV_FILE="${SKELL_ENV_FILE:-/etc/skell/skell.env}"

if [[ -f "$SKELL_ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$SKELL_ENV_FILE"
    log "INFO" "SKELL environment loaded."
fi

# ---------------------------------------------------------------------------
# 1.0 – GRUB env tool + kernelopts baseline
# ---------------------------------------------------------------------------
log "INFO" "GRUB environment bootstrap..."

GRUBENV_CMD=""

if command -v grub-editenv >/dev/null 2>&1; then
    GRUBENV_CMD="grub-editenv"
elif command -v grub2-editenv >/dev/null 2>&1; then
    GRUBENV_CMD="grub2-editenv"
else
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "DRY" "Would run: apt update -y"
        log "DRY" "Would run: apt install -y --no-install-recommends grub-common grub2-common"
    else
        run apt update -y
        run apt install -y --no-install-recommends grub-common grub2-common
    fi
fi

# Telepítés után újradetektálás
if command -v grub-editenv >/dev/null 2>&1; then
    GRUBENV_CMD="grub-editenv"
elif command -v grub2-editenv >/dev/null 2>&1; then
    GRUBENV_CMD="grub2-editenv"
else
    log "FATAL" "No grub-editenv/grub2-editenv found even after install."
    exit 1
fi

log "INFO" "GRUB env tool: $GRUBENV_CMD"

ensure_kernelopts() {
    local existing current_cmdline

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "DRY" "Would check kernelopts in grubenv and initialize baseline if missing."
        return 0
    fi

    existing="$($GRUBENV_CMD - list 2>/dev/null | grep '^kernelopts=' || true)"

    if [[ -n "$existing" ]]; then
        log "INFO" "kernelopts already present in grubenv → leaving as-is."
        return 0
    fi

    if [[ -r /proc/cmdline ]]; then
        current_cmdline="$(cat /proc/cmdline 2>/dev/null || true)"
    else
        current_cmdline=""
    fi

    if [[ -z "$current_cmdline" ]]; then
        log "WARN" "Could not read /proc/cmdline – kernelopts baseline will not be initialized."
        return 0
    fi

    run "$GRUBENV_CMD" - set "kernelopts=$current_cmdline"
    log "INFO" "kernelopts baseline initialized from /proc/cmdline."
}

ensure_kernelopts

# ---------------------------------------------------------------------------
# 1.5 – JAVÍTÁS: Zero-Trust: Systemd Csomagrögzítés (APT Pinning)
# ---------------------------------------------------------------------------
# log "INFO" "Applying APT Pinning to prevent Systemd installation (Priority -1)..."
# 
# if [[ "$DRY_RUN" -eq 0 ]]; then
#     run mkdir -p /etc/apt/preferences.d || log "WARN" "/etc/apt/preferences.d already exists or mkdir failed."
# 
#     cat > "$SYSTEMD_PREF_FILE" << EOF
# Blokkolja a Systemd komponensek telepítését a Zero-Trust elv miatt.
# Package: systemd systemd-sysv libsystemd0 udev
# Pin: release *
# Pin-Priority: -1
# 
# Package: *systemd*
# Pin: release *
# Pin-Priority: -1
# EOF
# 
#     run chmod 644 "$SYSTEMD_PREF_FILE"
#     log "INFO" "APT Pinning file $SYSTEMD_PREF_FILE created successfully."
# else
#     log "DRY" "Would create APT Pinning file to block Systemd."
# fi
# 
# # ---------------------------------------------------------------------------
# 2.0 – APT update + toolchain + memguard deps + security baseline
# ---------------------------------------------------------------------------
run apt update -y

# 📦 JAVÍTÁS: Töröltük a git-et és a vim-nox-ot.
ESSENTIAL_PKGS=(
    build-essential
    gcc
    make
    curl
    wget
    ca-certificates
    gnupg
    pkg-config
)

MEMGUARD_DEPS=(
    linux-headers-$(uname -r)
    libelf-dev
)

SECURITY_BASE_PKGS=(
    auditd
    apparmor
    apparmor-utils
)

install_packages() {
    local pkgs=("$@")
    local line
    line=$(printf "%s " "${pkgs[@]}")
    run apt install -y --no-install-recommends $line
}

install_packages "${ESSENTIAL_PKGS[@]}"
install_packages "${MEMGUARD_DEPS[@]}"
install_packages "${SECURITY_BASE_PKGS[@]}"

# ---------------------------------------------------------------------------
# 3.0 – ldconfig sanity check
# ---------------------------------------------------------------------------
LD_LOG="/var/log/whitevenom_ld_writable.log"

ld_paths_sanity_check() {
    log "INFO" "ldconfig sanity..."

    local lib_paths
    lib_paths=$(ldconfig -v 2>/dev/null | awk -F':' '/:$/ {print $1}')

    : > "$LD_LOG" 2>/dev/null || true

    while IFS= read -r path; do
        [[ -z "$path" || ! -d "$path" ]] && continue
        # ⚠️ JAVÍTÁS: Eltávolítva a || true a find parancsról!
        run find "$path" -maxdepth 1 -type f -perm -0002 -print >> "$LD_LOG"
    done <<< "$lib_paths"

    if [[ -s "$LD_LOG" ]]; then
        log "WARN" "World-writable libs detected. See: $LD_LOG"
    else
        log "INFO" "ldconfig OK"
    fi
}

ld_paths_sanity_check

# ---------------------------------------------------------------------------
# 4.0 – Baseline dirs
# ---------------------------------------------------------------------------
BASE_BACKUP_DIR="/var/backups/skell_backups"
BASE_LOG_DIR="/var/log/whitevenom"
BASE_TMP_DIR="/var/tmp/whitevenom"

for d in "$BASE_BACKUP_DIR" "$BASE_LOG_DIR" "$BASE_TMP_DIR"; do
    if [[ ! -d "$d" ]]; then
        run mkdir -p "$d"
        run chmod 700 "$d"
    fi
done

# ---------------------------------------------------------------------------
# 5.0 – Canary marker
# ---------------------------------------------------------------------------
CANARY_FILE="/etc/whitevenom_canary"

if [[ ! -f "$CANARY_FILE" ]]; then
    if [[ "$DRY_RUN" -eq 0 ]]; then
        echo "WhiteVenom baseline initialized: $(date -Iseconds)" > "$CANARY_FILE"
        chmod 600 "$CANARY_FILE"
    else
        log "DRY" "Create $CANARY_FILE"
    fi
fi


# ---------------------------------------------------------------------------
# 6.0 – GRUB cmdline hardening inject (primary: /etc/default/grub)
#       Goal: ensure CPU vuln mitigations are passed to the kernel via grub.cfg
# ---------------------------------------------------------------------------
grub_cmdline_hardening_inject() {
    log "INFO" "GRUB cmdline hardening inject..."

    local TS BACKUP_DIR GRUB_CFG
    TS="$(date +%Y%m%d-%H%M%S)"
    BACKUP_DIR="${BASE_BACKUP_DIR}/grub_inject"
    GRUB_CFG="/etc/default/grub"

    # Canonical mitigation tokens (space-separated, idempotent by key)
    local WANT_OPTS
    WANT_OPTS="meltdown=on l1tf=full,force smt=full,nosmt spectre_v2=on spec_store_bypass_disable=seccomp slab_nomerge=yes mce=0 pti=on"

    if [[ ! -f "$GRUB_CFG" ]]; then
        log "FATAL" "Missing $GRUB_CFG – cannot inject kernel cmdline."
        exit 57
    fi

    if [[ "$DRY_RUN" -eq 0 ]]; then
        mkdir -p "$BACKUP_DIR"
        chmod 700 "$BACKUP_DIR"
        # Preserve ownership/mode; timestamp is in filename
        cp -a "$GRUB_CFG" "$BACKUP_DIR/default_grub.bak.$TS" 2>/dev/null || true
        [[ -f /boot/grub/grubenv ]] && cp -a /boot/grub/grubenv "$BACKUP_DIR/grubenv.bak.$TS" 2>/dev/null || true
    fi

    # Helpers
    strip_quotes() {
        local s="$1"
        s="${s#\"}"; s="${s%\"}"
        printf "%s" "$s"
    }

    sed_escape_repl() {
        # Escape for sed replacement part (delimiter '|')
        local s="$1"
        s="${s//\/\\}"
        s="${s//&/\&}"
        s="${s//|/\|}"
        printf "%s" "$s"
    }

    get_var_value() {
        local var="$1"
        local line
        line="$(grep -E "^${var}=" "$GRUB_CFG" 2>/dev/null | head -n1 || true)"
        if [[ -z "$line" ]]; then
            printf "%s" ""
            return 0
        fi
        strip_quotes "${line#*=}"
    }

    var_exists() {
        local var="$1"
        grep -qE "^${var}=" "$GRUB_CFG" 2>/dev/null
    }

    set_var_value() {
        local var="$1"
        local val="$2"
        local esc
        esc="$(sed_escape_repl "$val")"

        if var_exists "$var"; then
            run sed -i -E "s|^${var}=.*|${var}=\"${esc}\"|" "$GRUB_CFG"
        else
            if [[ "$DRY_RUN" -eq 1 ]]; then
                log "DRY" "Would append: ${var}=\"${val}\" to $GRUB_CFG"
            else
                printf '
%s="%s"
' "$var" "$val" >> "$GRUB_CFG"
            fi
        fi
    }

    token_key() {
        local t="$1"
        if [[ "$t" == *"="* ]]; then
            printf "%s" "${t%%=*}"
        else
            printf "%s" "$t"
        fi
    }

    # Build want-keys map
    declare -A WANT_KEYS
    local w
    for w in $WANT_OPTS; do
        WANT_KEYS["$(token_key "$w")"]=1
    done

    # Read current values
    local CUR_LINUX CUR_DEFAULT
    CUR_LINUX="$(get_var_value GRUB_CMDLINE_LINUX)"
    CUR_DEFAULT="$(get_var_value GRUB_CMDLINE_LINUX_DEFAULT)"

    # Normalize whitespace
    CUR_LINUX="$(echo "$CUR_LINUX" | sed -e 's/^[[:space:]]\+//' -e 's/[[:space:]]\+/ /g' -e 's/[[:space:]]$//')"
    CUR_DEFAULT="$(echo "$CUR_DEFAULT" | sed -e 's/^[[:space:]]\+//' -e 's/[[:space:]]\+/ /g' -e 's/[[:space:]]$//')"

    # 1) Ensure mitigations live in GRUB_CMDLINE_LINUX (applies to normal + recovery entries)
    declare -A SEEN
    local NEW_LINUX="" tok key
    for tok in $CUR_LINUX; do
        key="$(token_key "$tok")"
        if [[ -n "${WANT_KEYS[$key]+x}" ]]; then
            continue
        fi
        NEW_LINUX="$NEW_LINUX $tok"
        SEEN["$key"]=1
    done
    for w in $WANT_OPTS; do
        key="$(token_key "$w")"
        if [[ -z "${SEEN[$key]+x}" ]]; then
            NEW_LINUX="$NEW_LINUX $w"
            SEEN["$key"]=1
        fi
    done
    NEW_LINUX="$(echo "$NEW_LINUX" | sed -e 's/^[[:space:]]\+//' -e 's/[[:space:]]\+/ /g' -e 's/[[:space:]]$//')"

    # 2) Sanitize GRUB_CMDLINE_LINUX_DEFAULT: keep "quiet" and other non-mitigation tokens,
    #    but remove any mitigation keys to avoid duplicates.
    local NEW_DEFAULT="" d
    for d in $CUR_DEFAULT; do
        key="$(token_key "$d")"
        if [[ -n "${WANT_KEYS[$key]+x}" ]]; then
            continue
        fi
        NEW_DEFAULT="$NEW_DEFAULT $d"
    done
    NEW_DEFAULT="$(echo "$NEW_DEFAULT" | sed -e 's/^[[:space:]]\+//' -e 's/[[:space:]]\+/ /g' -e 's/[[:space:]]$//')"

    log "INFO" "GRUB_CMDLINE_LINUX (current): ${CUR_LINUX:-<empty>}"
    log "INFO" "GRUB_CMDLINE_LINUX (new):     ${NEW_LINUX:-<empty>}"
    log "INFO" "GRUB_CMDLINE_LINUX_DEFAULT (current): ${CUR_DEFAULT:-<empty>}"
    log "INFO" "GRUB_CMDLINE_LINUX_DEFAULT (new):     ${NEW_DEFAULT:-<empty>}"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "DRY" "Would write /etc/default/grub (GRUB_CMDLINE_LINUX + sanitize DEFAULT), then run update-grub."
        return 0
    fi

    set_var_value GRUB_CMDLINE_LINUX "$NEW_LINUX"
    # Only set DEFAULT if it exists OR we already have something to keep; do not force-create it
    if var_exists GRUB_CMDLINE_LINUX_DEFAULT; then
        set_var_value GRUB_CMDLINE_LINUX_DEFAULT "$NEW_DEFAULT"
    fi

    if command -v update-grub >/dev/null 2>&1; then
        run update-grub
        log "INFO" "update-grub OK."
    elif command -v grub-mkconfig >/dev/null 2>&1; then
        run grub-mkconfig -o /boot/grub/grub.cfg
        log "INFO" "grub-mkconfig OK."
    else
        log "WARN" "No update-grub/grub-mkconfig found; grub.cfg not regenerated."
    fi

    # Optional audit marker: keep grubenv kernelopts in sync (does not drive boot on Debian by default)
    if [[ -n "${GRUBENV_CMD:-}" ]]; then
        run "$GRUBENV_CMD" - set "kernelopts=$WANT_OPTS"
        log "INFO" "grubenv kernelopts audit marker updated."
    fi

    log "INFO" "GRUB cmdline hardening inject done. Backup: $BACKUP_DIR"
}

grub_cmdline_hardening_inject
# ---------------------------------------------------------------------------
# END
# ---------------------------------------------------------------------------
log "INFO" "Mode: $MODE"
log "INFO" "GRUB env tool: $GRUBENV_CMD"
log "INFO" "Essentials + memguard deps installed"
log "INFO" "Baseline dirs ready"
log "INFO" "LD sanity log: $LD_LOG"
log "INFO" "00_install complete."
log "INFO" "END."

exit 0
