#!/bin/bash
# ------------------------------------------------------------------
# 17_module_blacklist.sh
# Kernel module blacklist + conditional module loading hardening
# Author: Bea Hardening Framework
# ------------------------------------------------------------------

set -euo pipefail
BACKUP_DIR="/var/backups/hardening"
BLACKLIST_FILE="/etc/modprobe.d/hardening_blacklist.conf"
HARDEN_CONF="/etc/hardening.conf"
LOGFILE="/var/log/hardening_module_blacklist.log"

mkdir -p "$BACKUP_DIR"

echo "[*] Module blacklist hardening started at $(date)" | tee -a "$LOGFILE"

# ------------------------------------------------------------------
# Step 1: Backup existing blacklist files
# ------------------------------------------------------------------
for f in /etc/modprobe.d/*.conf; do
    [ -f "$f" ] && cp "$f" "$BACKUP_DIR/$(basename "$f").bak_$(date +%F_%H%M%S)" && \
        echo "[OK] Backed up $f" | tee -a "$LOGFILE"
done

# ------------------------------------------------------------------
# Step 2: Create new blacklist file
# ------------------------------------------------------------------
cat << 'EOF' > "$BLACKLIST_FILE"
# Custom Bea hardening blacklist (critical modules)
blacklist i2c-piix4
blacklist snd-soc-max98090
blacklist snd-soc-rt5640
blacklist sns-soc-rl16231
blacklist appledisplay
blacklist apple_bl
blacklist appletouch
blacklist ac97_bus
blacklist soundcore
blacklist pcspker
blacklist usb-storage
blacklist hid-apple
blacklist hid-appleir
blacklist applesmc
blacklist ipddp
blacklist apple-gmux
blacklist appletalk
blacklist macmodes
blacklist hid-hyperv
blacklist hyperv-keyboard
blacklist hyperv_fb
blacklist hv_balloon
blacklist hv_vmbus
blacklist hv_storvsc
blacklist sp5100_tco
EOF

chmod 644 "$BLACKLIST_FILE"
echo "[OK] New blacklist file created at $BLACKLIST_FILE" | tee -a "$LOGFILE"

# ------------------------------------------------------------------
# Step 3: Attempt to unload listed modules (if loaded)
# ------------------------------------------------------------------
for mod in $(awk '/^blacklist/ {print $2}' "$BLACKLIST_FILE"); do
    if lsmod | grep -q "^$mod"; then
        if modprobe -r "$mod" 2>/dev/null; then
            echo "[OK] Removed loaded module: $mod" | tee -a "$LOGFILE"
        else
            echo "[WARN] Could not remove module: $mod (in use or protected)" | tee -a "$LOGFILE"
        fi
    fi
done

# ------------------------------------------------------------------
# Step 4: Conditional module locking logic
# ------------------------------------------------------------------
DISABLE_MODULE_LOADING_AFTER_BOOT="false"
if [ -f "$HARDEN_CONF" ]; then
    DISABLE_MODULE_LOADING_AFTER_BOOT=$(grep -E '^DISABLE_MODULE_LOADING_AFTER_BOOT=' "$HARDEN_CONF" | cut -d= -f2)
fi

if [ "$DISABLE_MODULE_LOADING_AFTER_BOOT" = "true" ]; then
    CURRENT_KERNEL=$(uname -r)
    LAST_KERNEL_FILE="/var/lib/hardening_last_kernel"
    LAST_KERNEL=""
    [ -f "$LAST_KERNEL_FILE" ] && LAST_KERNEL=$(cat "$LAST_KERNEL_FILE")

    if [ "$CURRENT_KERNEL" != "$LAST_KERNEL" ]; then
        echo "[NOTICE] Kernel version change detected ($LAST_KERNEL → $CURRENT_KERNEL). Skipping disable for now." | tee -a "$LOGFILE"
        echo "$CURRENT_KERNEL" > "$LAST_KERNEL_FILE"
    elif pgrep -x "apt" >/dev/null || pgrep -x "dpkg" >/dev/null; then
        echo "[NOTICE] Package operation detected, skipping module lock." | tee -a "$LOGFILE"
    else
        echo 1 > /proc/sys/kernel/modules_disabled
        echo "[OK] Kernel module loading disabled until next reboot." | tee -a "$LOGFILE"
    fi
else
    echo "[INFO] Module loading left enabled (per /etc/hardening.conf)" | tee -a "$LOGFILE"
fi

echo "[*] Module blacklist hardening complete." | tee -a "$LOGFILE"
