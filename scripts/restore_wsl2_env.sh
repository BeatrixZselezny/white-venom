#!/bin/bash
# ==========================================================
#  Debian Developer Environment Restore Script
#  Author: Bea’s AI partner 🐱
# ==========================================================

set -e

BACKUP_DIR="$HOME/Debian_Backup"
LOGFILE="$BACKUP_DIR/restore_log_$(date +%Y%m%d_%H%M).txt"

echo "🐧 Debian Environment Restore indul..."
echo "Backup könyvtár: $BACKUP_DIR"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ A backup könyvtár nem található: $BACKUP_DIR"
    echo "Másold át a WSL2 mentést ebbe a könyvtárba, majd futtasd újra."
    exit 1
fi

# === 1. Alap csomagok telepítése ===
echo "📦 Alap fejlesztői csomagok telepítése..."
sudo apt update -y
sudo apt install -y git maven openjdk-17-jdk postgresql curl unzip

# === 2. Telepített csomaglista visszaállítása (ha van) ===
PKG_FILE=$(ls "$BACKUP_DIR"/debian_installed_packages_*.txt 2>/dev/null | head -n 1)
if [ -f "$PKG_FILE" ]; then
    echo "🧰 Csomaglista visszaállítása..."
    sudo dpkg --set-selections < "$PKG_FILE"
    sudo apt-get dselect-upgrade -y || echo "⚠️ dselect-upgrade hibát adott, de folytatom."
fi

# === 3. Home könyvtár visszaállítása ===
HOME_BACKUP=$(ls "$BACKUP_DIR"/home_backup_*.tar.gz 2>/dev/null | head -n 1)
if [ -f "$HOME_BACKUP" ]; then
    echo "🏠 Home könyvtár visszaállítása..."
    tar -xzf "$HOME_BACKUP" -C "$HOME"
fi

# === 4. Maven repo visszaállítása ===
M2_BACKUP=$(ls "$BACKUP_DIR"/maven_repo_*.tar.gz 2>/dev/null | head -n 1)
if [ -f "$M2_BACKUP" ]; then
    echo "🪶 Maven repository visszaállítása..."
    tar -xzf "$M2_BACKUP" -C "$HOME"
fi

# === 5. SSH & GPG kulcsok ===
SSH_BACKUP=$(ls "$BACKUP_DIR"/ssh_gpg_*.tar.gz 2>/dev/null | head -n 1)
if [ -f "$SSH_BACKUP" ]; then
    echo "🔐 SSH és GPG kulcsok visszaállítása..."
    tar -xzf "$SSH_BACKUP" -C "$HOME"
    chmod 700 "$HOME/.ssh" 2>/dev/null || true
    chmod 600 "$HOME/.ssh"/* 2>/dev/null || true
fi

# === 6. Projektek visszaállítása ===
PROJECT_BACKUP=$(ls "$BACKUP_DIR"/dev_projects_*.tar.gz 2>/dev/null | head -n 1)
if [ -f "$PROJECT_BACKUP" ]; then
    echo "📁 Fejlesztési projektek visszaállítása..."
    mkdir -p "$HOME/w3school"
    tar -xzf "$PROJECT_BACKUP" -C "$HOME/w3school"
fi

# === 7. PostgreSQL adatbázis visszaállítása ===
PG_BACKUP=$(ls "$BACKUP_DIR"/postgres_all_*.sql 2>/dev/null | head -n 1)
if [ -f "$PG_BACKUP" ]; then
    echo "🐘 PostgreSQL adatbázis visszaállítása..."
    sudo systemctl enable postgresql || true
    sudo systemctl start postgresql || true

    sudo -u postgres psql < "$PG_BACKUP" 2>>"$LOGFILE" || \
        echo "⚠️ PostgreSQL visszaállítás sikertelen, ellenőrizd a logot." >> "$LOGFILE"
fi

# === 8. Docker image-ek visszaállítása (ha van Docker) ===
DOCKER_BACKUP=$(ls "$BACKUP_DIR"/docker_images_*.tar 2>/dev/null | head -n 1)
if [ -f "$DOCKER_BACKUP" ]; then
    if command -v docker &>/dev/null; then
        echo "🐳 Docker image-ek visszaállítása..."
        sudo docker load -i "$DOCKER_BACKUP"
    else
        echo "⚠️ Docker nincs telepítve, kihagyva."
    fi
fi

# === 9. Tulajdonjog és jogosultságok rendbehozása ===
echo "🧹 Jogosultságok helyreállítása..."
sudo chown -R "$USER:$USER" "$HOME"

# === 10. Befejezés ===
echo "✅ Visszaállítás kész!"
echo "Log fájl: $LOGFILE"
ls -lh "$BACKUP_DIR"

echo "✨ Üdv újra natív Debianon, Bea 🐱"
