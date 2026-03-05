#!/bin/bash
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
BRANCH_BACKUP_DIR="${BACKUP_DIR:-/var/backups/debootstrap_integrity/08}"
# Globális log függvényt feltételezünk
log() { echo "$(date +%F' '%T) $*"; }

# Ellenőrzés: root user
if [ "$(id -u)" -ne 0 ]; then
    log "[ERROR] Run as root!" >&2
    exit 1
fi

# --- TRANZAKCIÓS TISZTÍTÁS (CLEANUP/ROLLBACK) ---
branch_cleanup() {
    log "[ALERT] Hiba történt a 08-as ág futása közben! Rollback a szabályokra..."
    
    # 1. Auditd szabályok visszaállítása (ha van backup)
    if [ -f "$RULES_FILE.bak" ]; then
        log "[ACTION] Auditd szabályok visszaállítása a backupból."
        mv "$RULES_FILE.bak" "$RULES_FILE"
        /sbin/augenrules --load || true # Szabályok újratöltése a visszaállított fájlból
    else
        log "[WARNING] Nincs backup a $RULES_FILE-ról, a szabályt törlöm."
        rm -f "$RULES_FILE"
    fi
    # A securetty fájlt nem állítjuk vissza, mivel a cél az eltávolítása volt.
    log "[ALERT] 08-as ág rollback befejezve."
}

# Hiba esetén a rollback funkció meghívása
trap branch_cleanup ERR

# --- 1. BACKUP (Tranzakció indul) ---
log "[PRECHECK] Készítek backupot a meglévő $RULES_FILE-ról."
mkdir -p "$BRANCH_BACKUP_DIR"
cp -a "$RULES_FILE" "$RULES_FILE.bak" 2>/dev/null || true

# --- 2. SECURETTY ELTÁVOLÍTÁSA ÉS AUDITD SZABÁLYOK GENERÁLÁSA ---

# Hardening: /etc/securetty eltávolítása, hogy megelőzze a tty alapú root logint
if [ -f "$SECURETTY_FILE" ]; then
    log "[HARDENING] $SECURETTY_FILE eltávolítása (Explicit Zero Trust Minimalizálás)."
    rm -f "$SECURETTY_FILE"
fi

log "[ACTION] $RULES_FILE létrehozása a Zero Trust szabályokkal."

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

# /etc/securetty figyelése (még ha töröltük is, a létrehozást naplózza!)
-w /etc/securetty -p wa -k secure-ttys

# Rendszerindítási és Init.d változások figyelése (SysV Init environment)
-w /etc/inittab -p wa -k init
-w /etc/init.d/ -p wa -k init
-w /etc/default/ -p wa -k init

# Kernel modulok figyelése (Rootkit prevenció)
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules

# 2. Hálózati és Biztonsági Konfiguráció figyelése (Hardening)
# Tűzfal beállítások figyelése (ip6tables a mi Zero Trust alapunk)
-w /sbin/ip6tables -p x -k firewall
-w /etc/ip6tables/ -p wa -k firewall

# DNS konfiguráció figyelése (resolv.conf a Zero Trust DNS-ünk!)
-w /etc/resolv.conf -p wa -k dns-conf

# Auditd saját konfigurációjának figyelése (detektor elleni védelem)
-w /etc/audit/ -p wa -k audit-conf

# 3. Privilégium Eszkaláció Figyelése (User Integrity)

# Sikertelen SU kísérletek rögzítése
-a always,exit -F arch=b64 -S execve -F path=/bin/su -F exit!=0 -k su-fail
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/su -F exit!=0 -k su-fail

# Sikertelen SUDO kísérletek rögzítése
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/sudo -F exit!=0 -k sudo-fail

# Login/User management események (felhasználói adatok olvasása)
-a always,exit -F arch=b64 -S openat -F dir=/var/log/tallylog -F success=0 -k login-fail
-a always,exit -F arch=b64 -S openat -F dir=/var/log/lastlog -F success=0 -k login-fail

# 4. Rendszerhívások figyelése (a jogosultsági modell megsértése)
# Minden jogosultságot igénylő rendszerhívás figyelése
-a always,exit -F arch=b64 -S setuid -S setgid -S setgroups -S setresuid -S setresgid -S setfsuid -S setfsgid -k privilege-change

# 5. Immutability (A szabályok után!)
-e 2
EOF
chmod 0640 "$RULES_FILE"

# --- 3. AUDITD SZABÁLYOK BETÖLTÉSE ---
log "[ACTION] Auditd szabályok betöltése a kerneltől."
if command -v augenrules >/dev/null 2>&1; then
    /sbin/augenrules --load
else
    log "[WARNING] augenrules nem található. Auditd szolgáltatás újraindítása..."
    service auditd restart || /etc/init.d/auditd restart || true
fi

log "[DONE] 08-as ág befejezve. Kritikus Auditd szabályok beállítva."
exit 0
