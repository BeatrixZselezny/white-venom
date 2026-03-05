#!/bin/bash
# branches/11_apparmor_config_hardening.sh
# AppArmor (MAC) telepítése és kritikus fájlrendszer jogosultságok szigorítása (Zero Trust).
set -euo pipefail

# --- KONZISZTENCIA ÉS KONFIG ---
LOGFILE="/var/log/apparmor_config_hardening.log"
AUDITD_RULES_FILE="/etc/audit/rules.d/99-hardening.rules"
SSHD_CONFIG="/etc/ssh/sshd_config"
UNBOUND_CONF_DIR="/etc/unbound/unbound.conf.d"
SYSCTL_DIR="/etc/sysctl.d"

# Fájlok listája a lezáráshoz a commit fázisban
CRITICAL_FILES=(
    /etc/init.d/*
    "$SSHD_CONFIG"
    /etc/ssh/ssh_config
    "$SYSCTL_DIR"/*
    "$AUDITD_RULES_FILE"
    "$UNBOUND_CONF_DIR"/*
)
UNLOCKED_FILES=() # Fájlok listája a chattr -i feloldásához
# Globális log függvényt feltételezünk
log() { echo "$(date +%F' '%T) $*" | tee -a "$LOGFILE"; }
log "" # Új szakasz

# Ellenőrzés: root user
if [ "$(id -u)" -ne 0 ]; then
    log "[ERROR] Run as root!" >&2
    exit 1
fi

# Feloldó funkció (tranzakció előtt/közben)
unlock_file() {
    local file="$1"
    if command -v chattr &> /dev/null && lsattr "$file" 2>/dev/null | grep -q "i"; then
        log "   -> $file feloldása (chattr -i)."
        chattr -i "$file" 
        UNLOCKED_FILES+=("$file")
    fi
}

# --- TRANZAKCIÓS TISZTÍTÁS (CLEANUP/ROLLBACK) ---
function branch_cleanup() {
    log "[CRITICAL ALERT] Hiba történt a 11-es ág futása közben! Megkísérlem a rollbacket..."
    
    # **chattr -i futtatása a feloldott/lezárt fájlokra.**
    for file in "${CRITICAL_FILES[@]}"; do
        if [ -f "$file" ] || [ -d "$file" ]; then
            log "   -> chattr -i futtatása $file fájlon."
            if command -v chattr &> /dev/null; then chattr -i "$file" 2>/dev/null || true; fi
        fi
    done

    # 1. AppArmor eltávolítása (ha van)
    log "[ACTION] AppArmor csomagok eltávolítása."
    apt-get purge -y apparmor apparmor-utils

    # 2. Fájlrendszer jogosultságok VISSZAÁLLÍTÁSA (alapértelmezett jogok)
    log "[WARNING] Fájlrendszer jogosultságok visszaállítása alapértelmezettre (755/644)."
    
    # Init.d visszaállítás (755)
    chmod 755 /etc/init.d || true
    chmod 755 /etc/init.d/* 2>/dev/null || true
    
    # SSHD config visszaállítás
    chmod 644 "$SSHD_CONFIG" 2>/dev/null || true
    chmod 644 /etc/ssh/ssh_config 2>/dev/null || true
    
    # Auditd és Sysctl.d visszaállítás
    chmod 644 "$SYSCTL_DIR"/* 2>/dev/null || true
    chmod 644 "$AUDITD_RULES_FILE" 2>/dev/null || true

    log "[CRITICAL ALERT] 11-es ág rollback befejezve. Kézi ellenőrzés szükséges!"
    exit 1
}
trap branch_cleanup ERR

# --- 1. FÁJLRENDSZER JOGOSULTSÁGOK SZIGORÍTÁSA ---
log "--- 1. FÁJLRENDSZER JOGOSULTSÁGOK SZIGORÍTÁSA (DAC Hardening) ---"

# 1.1 Fájlok feloldása a jogosultságok módosítása előtt
for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ] || [ -d "$file" ]; then
        unlock_file "$file"
    fi
done

# Könyvtárak Jogosultságának Megerősítése
# **JAVÍTOTT: 750 (rwxr-x---) a könyvtárakra (Zero Trust).**
log "[ACTION] Kritikus könyvtárak jogosultságának megerősítése 750-re."
chmod 750 /etc/init.d
chmod 750 /etc/sysctl.d
chmod 750 /etc/audit/rules.d

# Init.d szkriptek szigorítása
# **JAVÍTOTT JOGOSULTSÁG: 755 (rwxr-xr-x). A futtatáshoz ez kell.**
log "[ACTION] /etc/init.d/* szigorítása 755-re (Zero Trust kompromisszum: futtatás engedélyezése)."
chown -R root:root /etc/init.d/
chmod 755 /etc/init.d/*

# SSH Konfiguráció (600/640: Kulcsfontosságú fájlok védelme)
# **JAVÍTOTT: SSHD config marad 600, a nyilvános config 640.**
log "[ACTION] SSH konfigurációs fájlok szigorítása (600/640)."
chown root:root "$SSHD_CONFIG"
chmod 600 "$SSHD_CONFIG" # Csak root olvashatja/írhatja
chown root:root /etc/ssh/ssh_config
chmod 640 /etc/ssh/ssh_config # Root:root, Csoport olvashatja (adm/hardening)

# Sysctl.d és Auditd Szabályok (640: Root írhatja, csak root csoport olvashatja)
# Az előzőekben is 640 volt, ezt tartjuk.
log "[ACTION] Kernel hardening beállítások szigorítása (640)."
chown -R root:root "$SYSCTL_DIR"
chmod 640 "$SYSCTL_DIR"/*
chown root:root "$AUDITD_RULES_FILE"
chmod 640 "$AUDITD_RULES_FILE"

# Unbound Konfiguráció (unbound:unbound 640/750)
log "[ACTION] Unbound konfigurációs fájlok jogosultságának beállítása (unbound:unbound)."
chown -R unbound:unbound "$UNBOUND_CONF_DIR" 2>/dev/null || true
chmod 640 "$UNBOUND_CONF_DIR"/* 2>/dev/null || true
chmod 750 "$UNBOUND_CONF_DIR" 2>/dev/null || true


# --- 2. APPARMOR TELEPÍTÉS ÉS KÉNYSZERÍTÉS (MAC) ---
log "--- 2. APPARMOR TELEPÍTÉS ÉS KÉNYSZERÍTÉS (MAC) ---"

log "[ACTION] AppArmor csomagok telepítése."
apt-get install -y apparmor apparmor-utils

# Kritikus profilok listája
PROFILES=(
    usr.sbin.sshd
    usr.bin.dpkg
    usr.sbin.cron
    usr.sbin.rsyslogd
    usr.sbin.unbound
)

# Profilok élesítése (enforce)
for prof in "${PROFILES[@]}"; do
    if [ -f "/etc/apparmor.d/$prof" ]; then
        log "[ACTION] $prof profil kényszerítése (enforce mode)."
        aa-enforce "$prof"
    else
        log "[WARNING] $prof profil nem található, kihagyva."
    fi
done

# --- 3. COMMIT (IMMUTABILITY LOCK) ---
log "--- 3. COMMIT (IMMUTABILITY LOCK) ---"

log "[ACTION] Kritikus fájlok lezárása (chattr +i)."
if command -v chattr &> /dev/null; then
    # Végigmegyünk a kritikus fájlokon és lezárjuk őket
    for file in "${CRITICAL_FILES[@]}"; do
        # A globbing miatt az * esetén is kezelni kell.
        if ls -d $file 2>/dev/null; then
            chattr +i $file 2>/dev/null || true
            log "   -> $file lezárva."
        fi
    done
fi


log "[DONE] 11-es ág befejezve. Fájlrendszer Jogosultságok és AppArmor (MAC) beállítva."
exit 0
