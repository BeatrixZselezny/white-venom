#!/bin/bash
# Step 0 - Minimal debootstrap telepítés
# Author: Beatrix Zelezny 🐱

TARGET=/mnt/debian_trixie
RELEASE=trixie
MIRROR=http://deb.debian.org/debian

echo "[0] debootstrap indul..."
debootstrap --arch=amd64 --variant=minbase $RELEASE $TARGET $MIRROR

echo "[0] Telepítés kész, chroot előkészítése..."
mount -t proc none $TARGET/proc
mount --rbind /sys $TARGET/sys
mount --rbind /dev $TARGET/dev
