#!/bin/bash
# WV_DRYRUN_GATE_07
if [[ "${1:-}" == "--dry-run" ]]; then
  echo "$(date +"%Y-%m-%d %H:%M:%S") [07_AUDISPD_RULES/DRY] skipping apply/load in dry-run";
  exit 0;
fi

# branches/08_audispd_rules.sh
# Auditd (Linux Audit Daemon) szabályainak beállítása.
# Zero Trust detektálás: kritikus fájl- és rendszerhívás figyelés.
set -euo pipefail

# --- KONZISZTENCIA ÉS KONFIG ---
LOGFILE="/var/log/audispd_hardening.log"
AUDITD_RULES_DIR="/etc/audit/rules.d"
RULES_FILE="$AUDITD_RULES_DIR/99-hardening.rules"
SECURETTY_FILE="/etc/securetty"
# Központosított backup hely használata
RULES_FILE_BACKUP="$RULES_FILE.bak.08"
# Globális log függvényt feltételezünk
log() { echo "$(date +%F' '%T) $*" | tee -a "$LOGFILE"; }
log "" # Új szakasz

# Ellenőrzés: root user
if [ "$(id -u)" -ne 0 ]; then
    log "[ERROR] Run as root!" >&2
    exit 1
fi

# --- TRANZAKCIÓS TISZTÍTÁS (CLEANUP/ROLLBACK) ---
function branch_cleanup() {
    log "[CRITICAL ALERT] Hiba történt a 07-es ág futása közben! Rollback a szabályokra..."
    
    # **JAVÍTÁS: A szabályfájl zárolásának feloldása**
    if command -v chattr &> /dev/null; then chattr -i "$RULES_FILE" 2>/dev/null || true; fi

    # 1. Auditd szabályok visszaállítása (ha van backup)
    if [ -f "$RULES_FILE_BACKUP" ]; then
        log "[ACTION] Auditd szabályok visszaállítása a backupból."
        mv "$RULES_FILE_BACKUP" "$RULES_FILE" || true
        /sbin/augenrules --load || true # Szabályok újratöltése
    else
        log "[WARNING] Nincs backup a $RULES_FILE-ról, a szabályt törlöm."
        rm -f "$RULES_FILE" || true
    fi
    
    log "[CRITICAL ALERT] 07-es ág rollback befejezve. Kézi ellenőrzés szükséges!"
    exit 1
}

# Hiba esetén a rollback funkció meghívása
trap branch_cleanup ERR

# --- 1. BACKUP (Tranzakció indul) ---
log "1. Készítek backupot a meglévő $RULES_FILE-ról."
# **JAVÍTÁS: Csak akkor készítünk backupot, ha a fájl létezik, és a fájlnév pontos.**
if [ -f "$RULES_FILE" ]; then
    cp "$RULES_FILE" "$RULES_FILE_BACKUP"
    # Fájl feloldása a módosításhoz, ha le volt zárva
    if command -v chattr &> /dev/null && lsattr "$RULES_FILE" 2>/dev/null | grep -q "i"; then
        chattr -i "$RULES_FILE" 
    fi
fi

# --- 2. SECURETTY ELTÁVOLÍTÁSA ÉS AUDITD SZABÁLYOK GENERÁLÁSA ---

# Hardening: /etc/securetty eltávolítása, hogy megelőzze a tty alapú root logint
if [ -f "$SECURETTY_FILE" ]; then
    log "[HARDENING] $SECURETTY_FILE eltávolítása (Explicit Zero Trust Minimalizálás)."
    rm -f "$SECURETTY_FILE"
fi

log "2. $RULES_FILE létrehozása a Zero Trust szabályokkal."

cat > "$RULES_FILE" <<'EOF'
# --- 99-hardening.rules (Zero Trust Audit) ---
# Alapszabály: Rögzítsük a kritikus változásokat a rendszer integritásának érdekében

# 1. Fájlrendszer kritikus integritásának figyelése
# Kritikus felhasználói és csoport adatbázisok figyelése
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope
-w /etc/securetty -p wa -k secure-ttys

# Rendszerindítási és Init.d változások figyelése (SysV Init environment)
-w /etc/inittab -p wa -k init
-w /etc/init.d/ -p wa -k init
-w /etc/default/ -p wa -k init

# 2. Kernel modulok figyelése (Rendszerhívás alapú Rootkit prevenció)
# **JAVÍTÁS: Csak a rendszerhívásokat figyeljük (pontosabb és minimalista).**
-a always,exit -F arch=b32 -S init_module -S delete_module -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules


# 3. Hálózati és Biztonsági Konfiguráció figyelése (Hardening)
-w /sbin/ip6tables -p x -k firewall
-w /etc/ip6tables/ -p wa -k firewall
-w /etc/resolv.conf -p wa -k dns-conf
-w /etc/audit/ -p wa -k audit-conf

# 4. Privilégium Eszkaláció Figyelése (User Integrity)

# Sikertelen SU kísérletek rögzítése
-a always,exit -F arch=b32 -S execve -F path=/bin/su -F exit!=0 -k su-fail
-a always,exit -F arch=b64 -S execve -F path=/bin/su -F exit!=0 -k su-fail
-a always,exit -F arch=b32 -S execve -F path=/usr/bin/su -F exit!=0 -k su-fail
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/su -F exit!=0 -k su-fail

# Sikertelen SUDO kísérletek rögzítése
-a always,exit -F arch=b32 -S execve -F path=/usr/bin/sudo -F exit!=0 -k sudo-fail
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/sudo -F exit!=0 -k sudo-fail

# Login/User management események (sikertelen kísérletek)
# **JAVÍTÁS: Explicit success=0 (sikertelen) figyelése az openat-nál.**
-a always,exit -F arch=b32 -S openat -F dir=/var/log/tallylog -F success=0 -k login-fail
-a always,exit -F arch=b64 -S openat -F dir=/var/log/tallylog -F success=0 -k login-fail
-a always,exit -F arch=b32 -S openat -F dir=/var/log/lastlog -F success=0 -k login-fail
-a always,exit -F arch=b64 -S openat -F dir=/var/log/lastlog -F success=0 -k login-fail

# 5. Rendszerhívások figyelése (jogosultsági modell megsértése)
# Minden jogosultságot igénylő rendszerhívás figyelése
# **JAVÍTÁS: Duplikált arch=b32.**
-a always,exit -F arch=b32 -S setuid -S setgid -S setgroups -S setresuid -S setresgid -S setfsuid -S setfsgid -k privilege-change
-a always,exit -F arch=b64 -S setuid -S setgid -S setgroups -S setresuid -S setresgid -S setfsuid -S setfsgid -k privilege-change

# 6. Immutability (A szabályok után!)
-e 2
EOF
chmod 0640 "$RULES_FILE"

# --- 3. AUDITD SZABÁLYOK BETÖLTÉSE ÉS LEZÁRÁSA (COMMIT) ---
log "3. Auditd szabályok betöltése és fájl lezárása."
if command -v augenrules >/dev/null 2>&1; then
    /sbin/augenrules --load
else
    log "[ACTION] augenrules nem található. Auditd szolgáltatás újraindítása (SysV init)."
    # **KRITIKUS JAVÍTÁS: Eltávolítva a || true a szolgáltatás újraindításáról!**
    service auditd restart || /etc/init.d/auditd restart
fi

# **JAVÍTÁS: Fájl lezárása (chattr +i)**
if command -v chattr &> /dev/null; then
    chattr +i "$RULES_FILE"
    log "[COMMIT] $RULES_FILE lezárva (chattr +i)."
fi

# Töröljük a sikeres futás után a backupot
rm -f "$RULES_FILE_BACKUP"

log "[DONE] 07-es ág befejezve. Kritikus Auditd szabályok beállítva és lezárva."
exit 0
