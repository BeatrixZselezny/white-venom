#!/bin/bash

# 🧭 Állítsd be a chroot gyökérkönyvtárát
CHROOT_DIR="/opt/testroot"

echo "🔧 Előkészítés: $CHROOT_DIR"

# 📁 Ellenőrzés
if [ ! -d "$CHROOT_DIR" ]; then
    echo "❌ A chroot könyvtár nem létezik: $CHROOT_DIR"
    exit 1
fi

# 🔗 Mountolások
echo "🔗 Mountolom a /proc, /sys, /dev fájlrendszereket..."
sudo mount -t proc /proc "$CHROOT_DIR/proc"
sudo mount --rbind /sys "$CHROOT_DIR/sys"
sudo mount --rbind /dev "$CHROOT_DIR/dev"

# 📦 Tesztkészlet másolása
echo "📦 Tesztkészlet másolása a chrootba..."
sudo cp -r ~/infra-snapshot-legacy "$CHROOT_DIR/root/"

# 🌐 Locale beállítás (opcionális)
echo "🌐 Locale exportálása..."
echo "export LANG=hu_HU.UTF-8" >> "$CHROOT_DIR/root/.bashrc"
echo "export LC_ALL=hu_HU.UTF-8" >> "$CHROOT_DIR/root/.bashrc"

# 🚪 Belépés
echo "🚪 Belépés a chrootba..."
sudo chroot "$CHROOT_DIR" /bin/bash
