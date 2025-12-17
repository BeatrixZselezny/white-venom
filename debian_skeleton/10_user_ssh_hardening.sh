#!/bin/bash
# branches/10_user_ssh_hardening.sh
# 'debiana' felhasználó létrehozása, SSH jelszó alapú bejelentkezés tiltása (Zero Trust).
set -euo pipefail

# --- KONZISZTENCIA ÉS KONFIG ---
LOGFILE="/var/log/user_hardening.log"
USERNAME="debiana"
SSHD_CONFIG="/etc/ssh/sshd_config"
# Globális log függvényt feltételezünk
log() { echo "$(date +%F' '%T) $*"; }

# Ellenőrzés: root user
if [ "$(id -u)" -ne 0 ]; then
    log "[ERROR] Run as root!" >&2
    exit 1
fi

# --- TRANZAKCIÓS TISZTÍTÁS (CLEANUP/ROLLBACK) ---
branch_cleanup() {
    log "[CRITICAL ALERT] Hiba történt a 10-es ág futása közben! Megkísérlem a rollbacket..."
    
    # 1. SSHD config visszaállítása
    if [ -f "$SSHD_CONFIG.bak" ]; then
        log "[ACTION] SSHD config visszaállítása."
        mv "$SSHD_CONFIG.bak" "$SSHD_CONFIG"
        service ssh restart || true
    fi
    
    # 2. Felhasználó törlése (ha a hiba előtte történt)
    if id "$USERNAME" >/dev/null 2>&1; then
        log "[ACTION] Felhasználó $USERNAME törlése."
        userdel -r "$USERNAME" || true
    fi

    log "[CRITICAL ALERT] 10-es ág rollback befejezve. Készülj fel a $USERNAME felhasználó manuális létrehozására!"
}
trap branch_cleanup ERR

# --- 1. SSHD HARDENING: JELSZÓ ALAPÚ BEJELENTKEZÉS TILTÁSA ---
log "[HARDENING] SSHD konfiguráció backupja és módosítása (Jelszó alapú login TILTÁSA)."
cp "$SSHD_CONFIG" "$SSHD_CONFIG.bak"

# 1.1 SSH Kulcs Kényszerítése
log "[ACTION] Kulcs alapú autentikáció kényszerítése (PasswordAuthentication no)."
sed -i '/^PasswordAuthentication/d' "$SSHD_CONFIG"
sed -i '/^PermitRootLogin/d' "$SSHD_CONFIG"
echo "PasswordAuthentication no" >> "$SSHD_CONFIG"
echo "PermitRootLogin no" >> "$SSHD_CONFIG" # Megerősítjük (ha már volt, most felülírja)

# 1.2 SSHD újraindítása
service ssh restart || true

# --- 2. FELHASZNÁLÓ LÉTREHOZÁSA ÉS JOGOSULTSÁGOK BEÁLLÍTÁSA ---
if id "$USERNAME" >/dev/null 2>&1; then
    log "[WARNING] Felhasználó $USERNAME már létezik, kihagyva a létrehozást."
else
    log "[ACTION] $USERNAME felhasználó létrehozása (home könyvtárral)."
    # Systemd nélkül a 'sudo' vagy 'adm' csoport a jogosultság emeléshez
    useradd -m -s /bin/bash "$USERNAME"
    
    # Biztosítjuk, hogy a felhasználó sudo-t használhasson
    log "[ACTION] $USERNAME hozzáadása a sudo csoporthoz."
    usermod -aG sudo "$USERNAME"
    
    # Zero Trust: mivel tiltottuk a jelszó alapú bejelentkezést, csak a kulccsal tud belépni!
    # A felhasználó jelszavát most nem állítjuk be, de a későbbi jelszó alapú konzol loginhoz szükséges lehet.
    # A felhasználó addig nem tud lokálisan bejelentkezni, amíg nincs beállítva jelszó, és távolról sem, amíg nincs SSH kulcs másolva.
    log "[WARNING] A felhasználó jelszavát be kell állítani a manuális fázisban: passwd $USERNAME"
fi


# --- 3. BIZTONSÁGI INTÉZKEDÉSEK UTÁNI ELLENŐRZÉS ---
if grep -q "PasswordAuthentication no" "$SSHD_CONFIG"; then
    log "[OK] SSH Jelszó Autentikáció KIKAPCSOLVA."
else
    log "[CRITICAL ERROR] SSH Hardening sikertelen! PasswordAuthentication még engedélyezve."
    exit 1
fi

log "[DONE] 10-es ág befejezve. $USERNAME felhasználó létrehozva, SSH kulcs kényszerítve."
exit 0
