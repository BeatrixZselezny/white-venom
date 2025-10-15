#!/bin/bash
# verify_apt_integrity.sh
# Pure Debian Trixie APT integrity and systemd-detector
# Author: Bea's AI sidekick 🐱
# License: MIT (because we’re civilized)

set -euo pipefail

LOGFILE="/var/log/apt_integrity.log"
APT_CONF_HASHFILE="/var/lib/apt_conf.hashes"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

echo "[$TIMESTAMP] Running APT integrity check..." | tee -a "$LOGFILE"

# 1️⃣ Ellenőrizzük a GPG kulcsokat és a forráslistát
if ! apt-get update -o Dir::Etc::sourcelist="sources.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0" >/dev/null 2>&1; then
    echo "[!] APT update failed — repository GPG verification issue!" | tee -a "$LOGFILE"
    exit 1
fi

# 2️⃣ Keresd a systemd-et minden telepített csomag között
if dpkg -l | grep -E 'systemd|libsystemd|systemd-sysv' >/dev/null 2>&1; then
    echo "[!] SYSTEMD DETECTED — purge it immediately!" | tee -a "$LOGFILE"
    dpkg -l | grep -E 'systemd|libsystemd|systemd-sysv' | tee -a "$LOGFILE"
    exit 2
else
    echo "[OK] No systemd found in installed packages." | tee -a "$LOGFILE"
fi

# 3️⃣ Ellenőrizzük az APT conf hash-eket
if [[ ! -f "$APT_CONF_HASHFILE" ]]; then
    echo "[INFO] Initializing APT config hash database..." | tee -a "$LOGFILE"
    find /etc/apt -type f -exec sha256sum {} \; > "$APT_CONF_HASHFILE"
    echo "[OK] Baseline hashes created." | tee -a "$LOGFILE"
else
    echo "[INFO] Checking APT config integrity..." | tee -a "$LOGFILE"
    TMPFILE=$(mktemp)
    find /etc/apt -type f -exec sha256sum {} \; > "$TMPFILE"
    if ! diff -q "$APT_CONF_HASHFILE" "$TMPFILE" >/dev/null; then
        echo "[!] WARNING: /etc/apt config files changed!" | tee -a "$LOGFILE"
        diff "$APT_CONF_HASHFILE" "$TMPFILE" | tee -a "$LOGFILE"
        echo "[ACTION] Review changes and update baseline if valid." | tee -a "$LOGFILE"
        rm -f "$TMPFILE"
        exit 3
    else
        echo "[OK] /etc/apt integrity verified — no changes." | tee -a "$LOGFILE"
    fi
    rm -f "$TMPFILE"
fi

# 4️⃣ Ellenőrizzük a GPG kulcsokat a keyringben
if apt-key list | grep -q "expired"; then
    echo "[!] WARNING: Expired APT GPG keys detected!" | tee -a "$LOGFILE"
    apt-key list | grep -A 1 "expired" | tee -a "$LOGFILE"
    exit 4
else
    echo "[OK] All APT GPG keys are valid." | tee -a "$LOGFILE"
fi

echo "[✓] APT integrity check completed successfully at $TIMESTAMP" | tee -a "$LOGFILE"
exit 0
