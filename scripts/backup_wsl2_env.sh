#!/bin/bash
# ==========================================================
#  Debian WSL2 Developer Environment Backup Script
#  Author: Bea’s AI partner 🐱
# ==========================================================

set -e

# === Alapbeállítások ===
BACKUP_DIR="/mnt/c/Users/$USER/Documents/Debian_Backup"
DATE=$(date +%Y%m%d_%H%M)
LOGFILE="$BACKUP_DIR/backup_log_$DATE.txt"

echo "🐧 WSL2 Debian Backup indul... ($DATE)"
echo "Backup könyvtár: $BACKUP_DIR"

mkdir -p "$BACKUP_DIR"

# === 1. Home könyvtár mentése ===
echo "📦 Home könyvtár mentése..."
tar -czf "$BACKUP_DIR/home_backup_$DATE.tar.gz" -C "$HOME" .

# === 2. PostgreSQL adatbázisok ===
if command -v pg_dumpall &>/dev/null; then
    echo "🐘 PostgreSQL dump készítése..."
    sudo -u postgres pg_dumpall > "$BACKUP_DIR/postgres_all_$DATE.sql" 2>>"$LOGFILE" || \
        echo "⚠️ PostgreSQL mentés nem sikerült. Ellenőrizd, fut-e a szolgáltatás." >> "$LOGFILE"
else
    echo "⛔ PostgreSQL nincs telepítve, lépés kihagyva." >> "$LOGFILE"
fi

# === 3. Maven repository mentése ===
if [ -d "$HOME/.m2" ]; then
    echo "🪶 Maven repository mentése..."
    tar -czf "$BACKUP_DIR/maven_repo_$DATE.tar.gz" -C "$HOME" .m2
fi

# === 4. Git projektek (pl. receptek) mentése ===
if [ -d "$HOME/w3school/objexamples" ]; then
    echo "🍳 Fejlesztési projektek mentése..."
    tar -czf "$BACKUP_DIR/dev_projects_$DATE.tar.gz" -C "$HOME/w3school" objexamples
fi

# === 5. Telepített csomagok listája ===
echo "📋 Telepített Debian csomagok listázása..."
dpkg --get-selections > "$BACKUP_DIR/debian_installed_packages_$DATE.txt"

# === 6. SSH & GPG kulcsok ===
if [ -d "$HOME/.ssh" ] || [ -d "$HOME/.gnupg" ]; then
    echo "🔐 SSH és GPG kulcsok mentése..."
    tar -czf "$BACKUP_DIR/ssh_gpg_$DATE.tar.gz" -C "$HOME" .ssh .gnupg 2>/dev/null || true
fi

# === 7. Docker image-ek mentése (ha van Docker) ===
if command -v docker &>/dev/null; then
    echo "🐳 Docker image-ek mentése..."
    docker save -o "$BACKUP_DIR/docker_images_$DATE.tar" $(docker images -q) 2>>"$LOGFILE" || \
        echo "⚠️ Docker image mentés kihagyva (üres vagy nem fut a daemon)." >> "$LOGFILE"
fi

# === 8. Befejezés ===
echo "✅ Backup kész!"
echo "Részletek: $LOGFILE"
ls -lh "$BACKUP_DIR"

# === 9. Összefoglaló logbejegyzés ===
{
    echo "====================="
    echo "WSL2 Backup befejezve: $DATE"
    echo "Mentett elemek:"
    ls -1 "$BACKUP_DIR"
    echo "====================="
} >> "$LOGFILE"

echo "✨ Minden elmentve a következő helyre:"
echo "   $BACKUP_DIR"
echo "Készen állsz a natív Debian életre, Bea 🐱"
