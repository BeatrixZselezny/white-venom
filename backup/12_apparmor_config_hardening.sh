#!/bin/bash
# branches/11_apparmor_config_hardening.sh
# AppArmor (MAC) telepítése és kritikus fájlrendszer jogosultságok szigorítása (Zero Trust).
set -euo pipefail

# --- KONZISZTENCIA ÉS KONFIG ---
LOGFILE="/var/log/apparmor_config_hardening.log"
AUDITD_RULES_FILE="/etc/audit/rules.d/99-hardening.rules"
SSHD_CONFIG="/etc/ssh/sshd_config"
UNBOUND_CONF_DIR="/etc/unbound/unbound.conf.d"
# Globális log függvényt feltételezünk
log() { echo "$(date +%F' '%T) $*" | tee -a "$LOGFILE"; }

# Ellenőrzés: root user
if [ "$(id -u)" -ne 0 ]; then
    log "[ERROR] Run as root!" >&2
    exit 1
fi

# --- TRANZAKCIÓS TISZTÍTÁS (CLEANUP/ROLLBACK) ---
branch_cleanup() {
    log "[CRITICAL ALERT] Hiba történt a 11-es ág futása közben! Megkísérlem a rollbacket..."
    
    # 1. AppArmor eltávolítása (ha van)
    log "[ACTION] AppArmor csomagok eltávolítása."
    apt-get purge -y apparmor apparmor-utils || true
    
    # 2. Fájlrendszer jogosultságok VISSZAÁLLÍTÁSA (alapértelmezett jogok)
    log "[WARNING] Fájlrendszer jogosultságok visszaállítása alapértelmezettre (755/644)."
    
    # Init.d visszaállítás (755)
    chmod 755 /etc/init.d/* || true
    
    # SSHD config visszaállítás
    chmod 644 "$SSHD_CONFIG" || true
    chmod 644 /etc/ssh/ssh_config || true
    
    # Auditd és Sysctl.d visszaállítás
    chmod 644 /etc/sysctl.d/* || true
    chmod 644 "$AUDITD_RULES_FILE" || true

    log "[CRITICAL ALERT] 11-es ág rollback befejezve. Fájlrendszer jogosultságok ellenőrzése szükséges!"
}
trap branch_cleanup ERR

# --- 1. FÁJLRENDSZER JOGOSULTSÁGOK SZIGORÍTÁSA ---
log "--- 1. FÁJLRENDSZER JOGOSULTSÁGOK SZIGORÍTÁSA ---"

# Könyvtárak Jogosultságának Megerősítése (755: bejárható, de nem írható)
log "[ACTION] Kritikus könyvtárak jogosultságának megerősítése 755-re."
chmod 755 /etc/init.d
chmod 755 /etc/sysctl.d
chmod 755 /etc/audit/rules.d
# /usr/share és /etc/ alapértelmezett jogai rendben vannak (755).

# Init.d szkriptek szigorítása (700: Csak root olvashat, írhat, futtathat)
log "[ACTION] /etc/init.d/* szigorítása 700-ra (Zero Trust: rejtés és írási jog tiltása)."
chown -R root:root /etc/init.d/
chmod 700 /etc/init.d/*

# SSH Konfiguráció (600/644: Kulcsfontosságú fájlok védelme)
log "[ACTION] SSH konfigurációs fájlok szigorítása (600/644)."
chown root:root "$SSHD_CONFIG"
chmod 600 "$SSHD_CONFIG"
chown root:root /etc/ssh/ssh_config
chmod 644 /etc/ssh/ssh_config

# Sysctl.d és Auditd Szabályok (640: Root írhatja, csak root csoport olvashatja)
log "[ACTION] Kernel hardening beállítások szigorítása (640)."
chown -R root:root /etc/sysctl.d/
chmod 640 /etc/sysctl.d/*
chown root:root "$AUDITD_RULES_FILE"
chmod 640 "$AUDITD_RULES_FILE"

# Unbound Konfiguráció (unbound:unbound 640/750)
log "[ACTION] Unbound konfigurációs fájlok jogosultságának beállítása (unbound:unbound)."
chown -R unbound:unbound "$UNBOUND_CONF_DIR" || true
chmod 640 "$UNBOUND_CONF_DIR"/* || true
chmod 750 "$UNBOUND_CONF_DIR" || true


# --- 2. APPARMOR TELEPÍTÉS ÉS KÉNYSZERÍTÉS (MAC) ---
log "--- 2. APPARMOR TELEPÍTÉS ÉS KÉNYSZERÍTÉS (MAC) ---"

log "[ACTION] AppArmor csomagok telepítése és kényszerítése."
apt-get install -y apparmor apparmor-utils

# Kritikus profilok listája (a memóriafiókból előhúzva és kiegészítve)
PROFILES=(
    usr.sbin.sshd
    usr.bin.dpkg
    usr.sbin.cron
    usr.sbin.rsyslogd
    usr.sbin.unbound # A Zero Trust DNS resolver!
)

# Profilok élesítése (enforce)
for prof in "${PROFILES[@]}"; do
    if [ -f "/etc/apparmor.d/$prof" ]; then
        log "[ACTION] $prof profil kényszerítése (enforce mode)."
        aa-enforce "$prof" || log "[WARNING] Nem sikerült kényszeríteni $prof-et. Ellenőrizd a logot!"
    else
        log "[WARNING] $prof profil nem található, kihagyva."
    fi
done

log "[DONE] 11-es ág befejezve. Fájlrendszer Jogosultságok és AppArmor (MAC) beállítva."
exit 0
