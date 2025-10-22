#!/bin/bash
# branches/10_user_ssh_hardening.sh
# 'debiana' felhasználó létrehozása, SSH jelszó alapú bejelentkezés tiltása (Zero Trust).
set -euo pipefail

# --- KONZISZTENCIA ÉS KONFIG ---
LOGFILE="/var/log/user_hardening.log"
USERNAME="debiana"
SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_CONFIG_BACKUP="$SSHD_CONFIG.bak.10"
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
branch_cleanup() {
    log "[CRITICAL ALERT] Hiba történt a 10-es ág futása közben! Megkísérlem a rollbacket..."
    
    # Visszazáratlan fájlok visszazárásának feloldása (ha leállt a commit előtt)
    for file in "${UNLOCKED_FILES[@]}"; do
        if command -v chattr &> /dev/null; then chattr -i "$file" 2>/dev/null || true; fi
    done

    # 1. SSHD config visszaállítása
    if [ -f "$SSHD_CONFIG_BACKUP" ]; then
        log "[ACTION] SSHD config visszaállítása a backupból."
        # **JAVÍTÁS: Konfiguráció feloldása a visszaállításhoz (ha már zároltuk volna).**
        unlock_file "$SSHD_CONFIG"
        mv "$SSHD_CONFIG_BACKUP" "$SSHD_CONFIG"
        # **KRITIKUS JAVÍTÁS: Eltávolítva a || true**
        service ssh restart || log "[ERROR] SSH szolgáltatás rollback újraindítás sikertelen!"
    fi
    
    # 2. Felhasználó törlése (ha a hiba előtte történt)
    if id "$USERNAME" >/dev/null 2>&1; then
        log "[ACTION] Felhasználó $USERNAME törlése."
        userdel -r "$USERNAME"
    fi

    log "[CRITICAL ALERT] 10-es ág rollback befejezve. Kézi ellenőrzés szükséges!"
    exit 1
}
trap branch_cleanup ERR

# --- 1. SSHD HARDENING: JELSZÓ ALAPÚ BEJELENTKEZÉS TILTÁSA ---

# Feloldjuk a konfigurációs fájlt, ha le volt zárva
unlock_file "$SSHD_CONFIG"

log "1. SSHD konfiguráció backupja és módosítása (Jelszó alapú login TILTÁSA)."
cp "$SSHD_CONFIG" "$SSHD_CONFIG_BACKUP"

# 1.1 SSH Kulcs Kényszerítése
log "[ACTION] Kulcs alapú autentikáció kényszerítése (PasswordAuthentication no)."
sed -i '/^PasswordAuthentication/d' "$SSHD_CONFIG"
sed -i '/^PermitRootLogin/d' "$SSHD_CONFIG"
echo "PasswordAuthentication no" >> "$SSHD_CONFIG"
echo "PermitRootLogin no" >> "$SSHD_CONFIG"

# --- 2. FELHASZNÁLÓ LÉTREHOZÁSA ÉS JOGOSULTSÁGOK BEÁLLÍTÁSA ---
if id "$USERNAME" >/dev/null 2>&1; then
    log "[WARNING] Felhasználó $USERNAME már létezik, kihagyva a létrehozást."
else
    log "2. $USERNAME felhasználó létrehozása."
    # Systemd nélkül a 'sudo' vagy 'adm' csoport a jogosultság emeléshez
    # **JAVÍTÁS: Az 'adm' csoportot használjuk a Debian-konzisztencia és minimalizmus érdekében.**
    useradd -m -s /bin/bash "$USERNAME"
    
    # Hozzáadjuk az 'adm' csoporthoz (sudo helyett)
    log "[ACTION] $USERNAME hozzáadása az adm csoporthoz."
    usermod -aG adm "$USERNAME"
    
    # Zero Trust: Jelszó zárolása (csak kulccsal engedélyezzük a belépést)
    # **KRITIKUS JAVÍTÁS: Jelszó zárolása az azonnali jelszó-hozzáférés megelőzésére.**
    log "[ACTION] A $USERNAME jelszavának zárolása (passwd -l)."
    passwd -l "$USERNAME"
fi


# --- 3. BIZTONSÁGI INTÉZKEDÉSEK VÉGLEGESÍTÉSE (COMMIT) ---

# 3.1 SSHD újraindítása
log "3.1 SSHD szolgáltatás újraindítása (hiba esetén megszakad)."
# **KRITIKUS JAVÍTÁS: Eltávolítva a || true a szolgáltatás újraindításáról!**
service ssh restart || /etc/init.d/ssh restart

# 3.2 SSHD konfigurációs fájl lezárása
log "3.2 $SSHD_CONFIG lezárása (chattr +i)."
if command -v chattr &> /dev/null; then
    chattr +i "$SSHD_CONFIG"
fi

# 3.3 Ellenőrzés
if grep -q "PasswordAuthentication no" "$SSHD_CONFIG"; then
    log "[OK] SSH Jelszó Autentikáció KIKAPCSOLVA."
else
    log "[CRITICAL ERROR] SSH Hardening sikertelen! PasswordAuthentication még engedélyezve."
    exit 1
fi

# Töröljük a sikeres futás után a backupot
rm -f "$SSHD_CONFIG_BACKUP"

log "[DONE] 10-es ág befejezve. $USERNAME felhasználó létrehozva, SSH kulcs kényszerítve és jelszó zárolva."
exit 0
