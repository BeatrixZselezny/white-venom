#!/bin/bash
# ============================================================================
#  15_dev_init.sh – Natív Debian Developer Environment Bootstrap
#  Zero Trust, init.d compatible, Temurin-25 + PostgreSQL + Git setup
#  Author: Bea & ChatGPT (2025-10-19)
# ============================================================================
set -euo pipefail

# ------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------
TEMURIN_VERSION="25"
TEMURIN_DIR="/usr/lib/jvm/temurin-${TEMURIN_VERSION}-jdk-amd64"
TEMURIN_GPG_URL="https://packages.adoptium.net/artifactory/api/gpg/key/public"
POSTGRES_VERSION="16"
LOGFILE="/var/log/dev_init.log"

timestamp() { date +"%Y-%m-%d %H:%M:%S"; }

echo "[$(timestamp)] Starting Dev Init Script..." | tee -a "$LOGFILE"

# ------------------------------------------------------------------------
# 1️⃣ Zero Trust / Security Checks
# ------------------------------------------------------------------------
echo "[$(timestamp)] Running Zero Trust checks..." | tee -a "$LOGFILE"

if [ "$(id -u)" -ne 0 ]; then
    echo "[$(timestamp)] ERROR: This script must be run as root." | tee -a "$LOGFILE"
    exit 1
fi

# ------------------------------------------------------------------------
# 2️⃣ Temurin-25 Installation
# ------------------------------------------------------------------------
echo "[$(timestamp)] Installing Temurin-${TEMURIN_VERSION}..." | tee -a "$LOGFILE"

# Create keyring directory if missing
mkdir -p /etc/apt/keyrings

# Download and install GPG key
wget -O - "$TEMURIN_GPG_URL" | gpg --dearmor | tee /etc/apt/keyrings/adoptium.asc > /dev/null

# Add repo
echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" \
    | tee /etc/apt/sources.list.d/adoptium.list

apt update
apt install -y temurin-${TEMURIN_VERSION}-jdk

# Update alternatives
update-alternatives --install /usr/bin/java java "$TEMURIN_DIR/bin/java" 1125
update-alternatives --set java "$TEMURIN_DIR/bin/java"

hash -r

# ------------------------------------------------------------------------
# 3️⃣ PostgreSQL (init.d) Installation
# ------------------------------------------------------------------------
echo "[$(timestamp)] Installing PostgreSQL-${POSTGRES_VERSION}..." | tee -a "$LOGFILE"
apt install -y postgresql-${POSTGRES_VERSION} postgresql-client-${POSTGRES_VERSION}

# Ensure init.d control
if [ -f /etc/init.d/postgresql ]; then
    echo "[$(timestamp)] PostgreSQL init.d script exists." | tee -a "$LOGFILE"
else
    echo "[$(timestamp)] WARNING: init.d script for PostgreSQL missing." | tee -a "$LOGFILE"
fi

# Start PostgreSQL
/etc/init.d/postgresql start

# ------------------------------------------------------------------------
# 4️⃣ Git + SSH Key Setup
# ------------------------------------------------------------------------
echo "[$(timestamp)] Configuring Git + SSH keys..." | tee -a "$LOGFILE"

read -p "Enter GitHub email for SSH key: " GIT_EMAIL
if [ ! -f /root/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f /root/.ssh/id_ed25519 -N ""
    echo "[$(timestamp)] SSH key generated."
else
    echo "[$(timestamp)] SSH key already exists."
fi

echo "Public key:"
cat /root/.ssh/id_ed25519.pub

# ------------------------------------------------------------------------
# 5️⃣ Bash Aliases / Environment Variables
# ------------------------------------------------------------------------
echo "[$(timestamp)] Setting up bash aliases and environment variables..." | tee -a "$LOGFILE"

BASH_ALIASES="/root/.bash_aliases"
touch "$BASH_ALIASES"

grep -qxF 'alias java25="java -version"' "$BASH_ALIASES" || echo 'alias java25="java -version"' >> "$BASH_ALIASES"
grep -qxF 'alias pgstart="sudo /etc/init.d/postgresql start"' "$BASH_ALIASES" || echo 'alias pgstart="sudo /etc/init.d/postgresql start"' >> "$BASH_ALIASES"
grep -qxF 'alias pgstop="sudo /etc/init.d/postgresql stop"' "$BASH_ALIASES" || echo 'alias pgstop="sudo /etc/init.d/postgresql stop"' >> "$BASH_ALIASES"
grep -qxF 'alias reloadinit="hash -r"' "$BASH_ALIASES" || echo 'alias reloadinit="hash -r"' >> "$BASH_ALIASES"

# Prompt to source aliases
echo "[$(timestamp)] Remember to source ~/.bash_aliases or restart shell." | tee -a "$LOGFILE"

# ------------------------------------------------------------------------
# 6️⃣ Final Checks
# ------------------------------------------------------------------------
echo "[$(timestamp)] Running final version checks..." | tee -a "$LOGFILE"
java -version | tee -a "$LOGFILE"
psql --version | tee -a "$LOGFILE"
git --version | tee -a "$LOGFILE"

echo "[$(timestamp)] Dev Init Script completed successfully!" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"
