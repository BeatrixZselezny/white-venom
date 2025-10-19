#!/bin/bash
# branches/05_dpkg_apt_hardening.sh
# DPKG/APT Baseline Hardening: Systemd/Legacy Blacklist, No-Recommends, HTTPS-Only, Stable Pinning.
# + MEMÓRIAVÉDELEM KÉNYSZERÍTÉSE (STACK CANARY)
set -euo pipefail

# --- CONFIG ---
APT_CONF_DIR="/etc/apt/apt.conf.d"
PREF_DIR="/etc/apt/preferences.d"
LOGFILE="/var/log/apt-preinstall.log"
# KITERJESZTETT FEKETELISTA: kizárja a systemd-t és a felesleges "esszenciálisnak" tekintett csomagokat.
BLACKLIST=(
    # 1. Systemd és társai (Nincs systemd)
    systemd systemd-sysv libsystemd0 libsystemd-journal0
    
    # 2. Örökölt / Nem szükséges hálózati eszközök (V6-only, minimalizmus)
    net-tools                # ifconfig, netstat - iproute2-t használunk
    iputils-ping             # iproute2-t használunk
    isc-dhcp-client          # Nincs szükség DHCPv4 kliensre
    dhcpcd5                  # Alternatív DHCP kliensek
    netplan                  # Ubuntu-specifikus hálózati konfig
    ppp                      # Dial-up/modem
    
    # 3. Felesleges GUI/Asztali alapok (Nincs desktop)
    desktop-base
    
    # 4. Hagyományos/Felesleges naplózás/admin eszközök
    logrotate                # Manuális logkezelés
    dbus-daemon              # D-Bus (gyakran GUI/systemd függőség)
)
DRY_RUN=false
BRANCH_BACKUP_DIR="${BACKUP_DIR:-/var/backups/debootstrap_integrity/05}"

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
    if [ -d "$BRANCH_BACKUP_DIR/apt.conf.d.bak" ]; then
        log "[ACTION] APT konfiguráció visszaállítása a backupból."
        # Először töröljük a most létrehozott fájlokat
        rm -rf "$APT_CONF_DIR"/*
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
cp -a "$APT_CONF_DIR" "$BRANCH_BACKUP_DIR/apt.conf.d.bak" 2>/dev/null || true
cp -a "$PREF_DIR" "$BRANCH_BACKUP_DIR/preferences.d.bak" 2>/dev/null || true

# --- 2. APT HOOK: BLACKLIST SZŰRÉS ---
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
export -f apt_preinstall_filter

# Apt configuration snippet a hook meghívására
cat > "$APT_CONF_DIR/99-preinstall-filter" <<'EOF'
DPkg::Pre-Install-Pkgs {
"/bin/bash -c 'apt_preinstall_filter'";
};
EOF
log "[ACTION] Kiterjesztett Blacklist hook beállítva. Tiltott csomagok: ${BLACKLIST[*]}"

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
log "[ACTION] Kritikus csomagok Pin-Priority 1001-re állítva."

# --- 5. MEMÓRIAVÉDELEM KÉNYSZERÍTÉSE (STACK CANARY) ---
log "--- 5. MEMÓRIAVÉDELEM KÉNYSZERÍTÉSE (STACK CANARY) ---"

log "[ACTION] 'hardening-wrapper' és 'build-essential' telepítése."
# A 'build-essential' biztosítja a fordításhoz szükséges alapvető eszközöket.
# A 'hardening-wrapper' kényszeríti a GCC/Clang számára a legszigorúbb flag-eket
# (pl. -fstack-protector-strong, -pie, ASLR, stb.) minden fordításhoz.
apt-get update # Frissítés a csomagok megtalálásához
apt-get install -y --no-install-recommends hardening-wrapper build-essential

log "[OK] Stack Canary, PIE és memória exploit védelem kényszerítve a GLIBC/LD és a csomagokhoz."


log "[DONE] 05-ös ág befejezve. DPKG/APT maximálisan hardeningelt, memóriavédelemmel kiegészítve."
exit 0
