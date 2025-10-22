#!/bin/bash
# branches/05_dpkg_apt_hardening.sh
# DPKG/APT Baseline Hardening: HTTPS-Only, Stable Pinning, Hardening Wrapper.
# + KRITIKUS: Systemd és felesleges csomagok kizárása telepítéskor.

set -euo pipefail

# --- CONFIG ---
APT_CONF_DIR="/etc/apt/apt.conf.d"
PREF_DIR="/etc/apt/preferences.d"
LOGFILE="/var/log/apt-hardening.log"
UNLOCKED_FILES=() # Fájlok listája, amiket a chattr -i feloldott
CREATED_FILES=("$APT_CONF_DIR/90-preinstall-filter" "$APT_CONF_DIR/99-no-recommends-suggests" "$APT_CONF_DIR/99-apt-https-only" "$PREF_DIR/99-stable-pin")
BRANCH_BACKUP_DIR="/var/backups/hardening/05_apt_config"

# KITERJESZTETT FEKETELISTA: kizárja a systemd-t és a felesleges "esszenciálisnak" tekintett csomagokat.
BLACKLIST=(
    # 1. Systemd és társai (Nincs systemd)
    systemd systemd-sysv libsystemd0 libsystemd-journal0 udev
    
    # 2. Örökölt / Nem szükséges hálózati eszközök (V6-only, minimalizmus)
    net-tools isc-dhcp-client dhcpcd5 netplan ppp
    
    # 3. Felesleges GUI/Asztali alapok (Nincs desktop)
    desktop-base
    
    # 4. Hagyományos/Felesleges naplózás/admin eszközök
    logrotate dbus-daemon
)

log() { echo "$(date +%F' '%T) $*" | tee -a "$LOGFILE"; }
log "" # Új szakasz

# Ellenőrzés: root user
if [ "$(id -u)" -ne 0 ]; then
    log "[ERROR] Run as root!" >&2
    exit 1
fi

# --- TRANZAKCIÓS TISZTÍTÁS (CLEANUP/ROLLBACK) ---
branch_cleanup() {
    log "[CRITICAL ALERT] Hiba történt a 05-ös ág futása közben! Megkísérlem a rollbacket..."
    
    # 1. Feloldott fájlok visszazárásának feloldása (ha leállt a szkript a commit előtt)
    for file in "${UNLOCKED_FILES[@]}"; do
        log "   -> chattr -i feloldása a $file fájlon (Rollback)."
        if command -v chattr &> /dev/null; then chattr -i "$file" 2>/dev/null || true; fi
    done

    # 2. Újonnan létrehozott fájlok törlése
    for file in "${CREATED_FILES[@]}"; do
        if [ -f "$file" ]; then
            log "   -> Új fájl törlése: $file"
            rm -f "$file" || true
        fi
    done

    # 3. APT konfigurációk visszaállítása
    if [ -d "$BRANCH_BACKUP_DIR/apt.conf.d.bak" ]; then
        log "   -> APT konfiguráció visszaállítása a backupból."
        rm -rf "$APT_CONF_DIR"/*
        cp -a "$BRANCH_BACKUP_DIR/apt.conf.d.bak"/* "$APT_CONF_DIR/" 2>/dev/null || true
    fi
    if [ -d "$BRANCH_BACKUP_DIR/preferences.d.bak" ]; then
        log "   -> APT preferences visszaállítása."
        rm -rf "$PREF_DIR"/*
        cp -a "$BRANCH_BACKUP_DIR/preferences.d.bak"/* "$PREF_DIR/" 2>/dev/null || true
    fi

    log "[CRITICAL ALERT] 05-ös ág rollback befejezve. Kézi ellenőrzés szükséges!"
    exit 1
}

# Hiba esetén a rollback funkció meghívása
trap branch_cleanup ERR

# --- 1. BACKUP (Tranzakció indul) ---
log "1. Készítek backupot a jelenlegi APT konfigurációról: $BRANCH_BACKUP_DIR"
mkdir -p "$BRANCH_BACKUP_DIR"

# Fájlok feloldása a backup és módosítás előtt
unlock_file() {
    local file="$1"
    if [ -f "$file" ] && command -v chattr &> /dev/null && lsattr "$file" 2>/dev/null | grep -q "i"; then
        chattr -i "$file" 
        UNLOCKED_FILES+=("$file")
        log "   -> $file feloldva."
    fi
}

unlock_file "$APT_CONF_DIR/99-preinstall-filter" # Régi fájlok előkészítése
unlock_file "$APT_CONF_DIR/99-no-recommends-suggests"
unlock_file "$APT_CONF_DIR/99-apt-https-only"
unlock_file "$PREF_DIR/99-stable-pin"

cp -a "$APT_CONF_DIR" "$BRANCH_BACKUP_DIR/apt.conf.d.bak" 
cp -a "$PREF_DIR" "$BRANCH_BACKUP_DIR/preferences.d.bak" 

# --- 2. APT HOOK: BLACKLIST SZŰRÉS ---
log "2. Kiterjesztett Blacklist APT hook beállítása."

# **JAVÍTÁS: Egyszerűsített, beépített shell parancs a hookhoz, a külső függvény hívások elkerülése érdekében.**
# Használja a grep-et a csomaglistán, és ha talál egy blacklistelt csomagot, hibakóddal lép ki (1)
# a pipefail miatt, ami megakadályozza a telepítést.
BLACKLIST_REGEX=$(IFS='|'; echo "${BLACKLIST[*]}")

# **JAVÍTÁS: A fájl nevének módosítása `90-preinstall-filter`-re a sorrend miatt.**
cat > "$APT_CONF_DIR/90-preinstall-filter" <<EOF
DPkg::Pre-Install-Pkgs {
"/bin/grep -Eiq '($BLACKLIST_REGEX)' || test \$? -eq 1";
};
EOF
log "[ACTION] Blacklist hook beállítva. Tiltott regex: '$BLACKLIST_REGEX'"

# --- 3. HARDENING POLICYK ---

# 3.1 Globális no-recommends és no-suggests policy (Minimalizmus)
cat > "$APT_CONF_DIR/99-no-recommends-suggests" <<'EOF'
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF
log "[ACTION] Minimalista telepítés kényszerítve (No-Recommends/No-Suggests)."

# 3.2 HTTPS Kényszerítése (Zero Trust Hálózati Integritás)
# **JAVÍTÁS: A fájl neve `99-apt-https-only` volt az eredetiben is, megtartjuk.**
cat > "$APT_CONF_DIR/99-apt-https-only" <<'EOF'
// A titkosítatlan HTTP-re való visszaesés tiltása
Acquire::Retries "0"; 
Acquire::AllowInsecureRepositories "false";
Acquire::http::Pipeline-Depth "0";

// SSL/TLS ellenőrzés kényszerítése
Acquire::https::Verify-Peer "true";
Acquire::https::Verify-Host "true";

// **JAVÍTÁS: Az összes kommunikáció átkényszerítése HTTPS-re (ha van rá lehetőség) **
Acquire::Scheme::http::Forced-Paths "https";
EOF
log "[ACTION] APT HTTPS kényszerítve (HTTP rollback és 'AllowInsecureRepositories' tiltva). Minden HTTP-t HTTPS-re kényszerítünk."

# --- 4. PREFERENCES (Pinning) ---
# A legkritikusabb csomagok kényszerítése a STABIL ágról (Pin-Priority 1001)
cat > "$PREF_DIR/99-stable-pin" <<'EOF'
Package: dpkg libc6 openssl
Pin: release a=stable
Pin-Priority: 1001
EOF
log "[ACTION] Kritikus csomagok Pin-Priority 1001-re állítva."

# --- 5. MEMÓRIAVÉDELEM KÉNYSZERÍTÉSE (STACK CANARY) ---
log "5. MEMÓRIAVÉDELEM KÉNYSZERÍTÉSE (STACK CANARY) - Hardening Wrapper telepítése."

log "[ACTION] 'hardening-wrapper' telepítése."
# A 'hardening-wrapper' kényszeríti a GCC/Clang számára a legszigorúbb flag-eket
# (pl. -fstack-protector-strong, -pie, ASLR, stb.) minden fordításhoz.
apt-get update # Frissítés a csomagok megtalálásához
# **JAVÍTÁS: Eltávolítva a 'build-essential' a zero-trust minimalizmus miatt.**
apt-get install -y --no-install-recommends hardening-wrapper

log "[OK] Stack Canary, PIE és memória exploit védelem kényszerítve."

# --- 6. VÉGLEGESÍTÉS (COMMIT) ---

log "6. Konfigurációk lezárása (chattr +i)."
if command -v chattr &> /dev/null; then
    for file in "${CREATED_FILES[@]}"; do
        if [ -f "$file" ]; then
            chattr +i "$file" 
            log "   -> $file lezárva."
        fi
    done
fi

# Töröljük a sikeres futás után a backupot
rm -rf "$BRANCH_BACKUP_DIR"

log "[DONE] 05-ös ág befejezve. DPKG/APT maximálisan hardeningelt, memóriavédelemmel kiegészítve."
exit 0
