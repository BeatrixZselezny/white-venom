#!/bin/bash
# ============================================================================
# Pure Debian Trixie Bootstrap Script (systemd-free, SysV init)
# Author: Bea + ChatGPT 🐱
# ============================================================================
# Usage:
#   Run from the Debian installer expert shell after mounting /mnt.
#   Example:
#       mount /dev/sda1 /mnt
#       chmod +x bootstrap_pure_debian_trixie.sh
#       ./bootstrap_pure_debian_trixie.sh
# ============================================================================

set -euo pipefail
export LANG=C

### --- CONFIG --- ###
TARGET="/mnt"
DEB_RELEASE="trixie"
MIRROR="http://deb.debian.org/debian/"
HOSTNAME="debian-pure"
USERNAME="bea"
TIMEZONE="Europe/Budapest"
ARCH="amd64"
### --- CONFIG END --- ###

echo "🐱 Starting pure Debian $DEB_RELEASE debootstrap on $TARGET ..."
sleep 2

### 1. Bootstrap the base system
debootstrap --arch=$ARCH $DEB_RELEASE $TARGET $MIRROR

### 2. Mount virtual filesystems
mount -t proc /proc $TARGET/proc
mount -t sysfs /sys $TARGET/sys
mount --rbind /dev $TARGET/dev
mount --rbind /run $TARGET/run

### 3. Basic configuration
cat <<EOF > $TARGET/etc/hostname
$HOSTNAME
EOF

cat <<EOF > $TARGET/etc/hosts
127.0.0.1   localhost
127.0.1.1   $HOSTNAME
EOF

ln -sf /usr/share/zoneinfo/$TIMEZONE $TARGET/etc/localtime

### 4. Enter chroot for package setup
cat <<'EOFCHROOT' > $TARGET/tmp/inside_chroot.sh
#!/bin/bash
set -euo pipefail

echo "🐾 Inside chroot: configuring pure Debian Trixie"

# Minimal essentials
apt-get update
apt-get install --no-install-recommends -y linux-image-amd64 grub-pc \
  bash-completion net-tools iproute2 ifupdown vim less sudo

# Install SysV init, remove systemd
apt-get install --no-install-recommends -y sysvinit-core sysvinit-utils
apt-get purge -y --auto-remove systemd systemd-sysv || true
apt-mark hold systemd || true

# Set root password
echo "Set root password:"
passwd

# Create user
useradd -m -s /bin/bash bea
passwd bea
adduser bea sudo

# Configure timezone
dpkg-reconfigure tzdata

# Optional: install SSH server
apt-get install --no-install-recommends -y openssh-server

# Configure GRUB
grub-install /dev/sda
update-grub

echo "✅ Base Debian Trixie system ready. Exit chroot to unmount and reboot."
EOFCHROOT

chmod +x $TARGET/tmp/inside_chroot.sh
chroot $TARGET /tmp/inside_chroot.sh
rm -f $TARGET/tmp/inside_chroot.sh

### 5. Cleanup
umount -R $TARGET/proc || true
umount -R $TARGET/sys || true
umount -R $TARGET/dev || true
umount -R $TARGET/run || true

echo "🎉 Debian Trixie Pure installation complete!"
echo "Now exit the installer shell, remove USB, and reboot into your new system."
