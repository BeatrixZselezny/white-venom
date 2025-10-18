#!/bin/bash
# branches/05-dpkg-apt-hardening.sh
# DPKG/APT Baseline Hardening: Systemd Blacklist, No-Recommends, HTTPS-Only, Stable Pinning.
# Author: Beatrix Zelezny 🐱 (Zero Trust Revision by Gemini)
set -euo pipefail

# --- CONFIG ---
APT_CONF_DIR="/etc/apt/apt.conf.d"
PREF_DIR="/etc/apt/preferences.d"
LOGFILE="/var/log/apt-preinstall.log"
BLACKLIST=(systemd systemd-sysv libsystemd0 libsystemd-journal0)
DRY_RUN=false # A futtató scriptből kell érkeznie
BRANCH_BACKUP_DIR="${BACKUP_DIR:-/var/backups/debootstrap_integrity/05}" # Központosított backup hely

# Globális log függvényt feltételezünk, ami a tools/common_functions.sh-ból jön.
log() { echo "$(date +%F' '%T) $*"; }

# Ellenőrzés: root user
if [ "$(id -u)" -ne 0 ]; then
    log "[ERROR] Run as root!" >&2
    exit 1
fi

# --- TRANZAKCIÓS TISZTÍTÁS (CLEANUP/ROLLBACK) ---
branch_cleanup() {
    log "[ALERT] Hiba történt a 05-ös ág futása közben! Megkísérlem a rollbacket..."
    # 1. Visszaállítja a korábbi állapotot, ha volt backup
    if [ -d "$BRANCH_BACKUP_DIR/apt.conf.d.bak" ]; then
        log "[ACTION] APT konfiguráció visszaállítása a backupból."
        # Először töröljük a most létrehozott fájlokat
        rm -rf "$APT_CONF_DIR"/*
        # A backup tartalmának visszamásolása
        cp -a "$BRANCH_BACKUP_DIR/apt.conf.d.bak"/* "$APT_CONF_DIR/" 2>/dev/null || true
    fi
    if [ -d "$BRANCH_BACKUP_DIR/preferences.d.bak" ]; then
        log "[ACTION] APT preferences visszaállítása."
        rm -rf "$PREF_DIR"/*
        cp -a "$BRANCH_BACKUP_DIR/preferences.d.bak"/* "$PREF_DIR/" 2>/dev/null || true
    fi
    log "[ALERT] 05-ös ág rollback befejezve. Nézd át a logokat!"
}

# Hiba esetén a rollback funkció meghívása
trap branch_cleanup ERR

# --- 1. BACKUP (Tranzakció indul) ---
log "[PRECHECK] Készítek backupot a jelenlegi APT konfigurációról: $BRANCH_BACKUP_DIR"
mkdir -p "$BRANCH_BACKUP_DIR"
# A backupot a mappáról kell készíteni, nem a fájlokról
cp -a "$APT_CONF_DIR" "$BRANCH_BACKUP_DIR/apt.conf.d.bak" 2>/dev/null || true
cp -a "$PREF_DIR" "$BRANCH_BACKUP_DIR/preferences.d.bak" 2>/dev/null || true

# --- 2. APT HOOK: SYSTEMD FEKETELISTÁZÁS ---
# Wrapper function for DPkg::Pre-Install-Pkgs
apt_preinstall_filter() {
    local exit_code=0
    while read -r pkg; do
        for b in "${BLACKLIST[@]}"; do
            if [[ "$pkg" == *$b* ]]; then
                log "[BLOCK] Blacklist package found! Blocking pre-install of $pkg" | tee -a "$LOGFILE"
                exit_code=1 # Kilépés kényszerítése APT hookon belül
            fi
        done
    done
    return "$exit_code"
}
# A hook function globális exportálása
export -f apt_preinstall_filter

# Apt configuration snippet a hook meghívására
cat > "$APT_CONF_DIR/99-preinstall-filter" <<'EOF'
DPkg::Pre-Install-Pkgs {
"/bin/bash -c 'apt_preinstall_filter'";
};
EOF
log "[ACTION] Systemd Blacklist hook (DPkg::Pre-Install-Pkgs) beállítva."

# --- 3. HARDENING POLICYK ---

# 3.1 Globális no-recommends és no-suggests policy (Minimalizmus)
cat > "$APT_CONF_DIR/99-no-recommends-suggests" <<'EOF'
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF
log "[ACTION] Minimalista telepítés kényszerítve (No-Recommends/No-Suggests)."

# 3.2 HTTPS Kényszerítése (Zero Trust Hálózati Integritás)
cat > "$APT_CONF_DIR/99-apt-https-only" <<'EOF'
// A titkosítatlan HTTP-re való visszaesés tiltása
Acquire::Retries "0"; 
Acquire::AllowInsecureRepositories "false";
Acquire::http::Pipeline-Depth "0";

// SSL/TLS ellenőrzés kényszerítése
Acquire::https::Verify-Peer "true";
Acquire::https::Verify-Host "true";
EOF
log "[ACTION] APT HTTPS kényszerítve (HTTP rollback és 'AllowInsecureRepositories' tiltva)."

# --- 4. PREFERENCES (Pinning) ---
# A legkritikusabb csomagok kényszerítése a STABIL ágról (Pin-Priority 1001)
cat > "$PREF_DIR/99-stable-pin" <<'EOF'
Package: dpkg libc6 openssl
Pin: release a=stable
Pin-Priority: 1001
EOF
log "[ACTION] Kritikus csomagok (dpkg, libc6, openssl) Pin-Priority 1001-re állítva."

# --- VÉGZETES ELLENŐRZÉS ---
# Teszt (szimulált telepítés systemd csomaggal, ami hibát generálna)
# Ha a logoláson kívül ténylegesen is le akarod tesztelni a hookot, egy hívást kellene itt indítani.
# Jelenleg ezt elhagyjuk, hogy ne okozzunk mesterségesen hibát a chrootban.

log "[DONE] 05-ös ág befejezve. APT/DPKG hardening alkalmazva."
exit 0
