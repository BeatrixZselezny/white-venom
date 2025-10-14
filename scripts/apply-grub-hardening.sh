#!/bin/bash

# apply-grub-hardening.sh
# Használat: sh apply-grub-hardening.sh [TARGET]
# TARGET default: /target  (Debian installer chroot target)

TARGET=${1:-/target}

echo "GRUB hardening alkalmazása a célrendszeren ($TARGET)"

# Ellenőrizzük, hogy a célrendszer a /boot/grub/grubenv fájlban található-e
if [ ! -f "$TARGET/boot/grub/grubenv" ]; then
  echo "A grubenv fájl nem található ($TARGET/boot/grub/grubenv). A script leáll."
  exit 1
fi

# Hozzáadjuk a hardening beállításokat a grubenv fájlhoz
echo "Hozzáadjuk a GRUB hardening beállításokat a grubenv fájlhoz."

# Készítünk egy biztonsági másolatot
cp "$TARGET/boot/grub/grubenv" "$TARGET/boot/grub/grubenv.bak"

# GRUB hardening paraméterek
grub_params="smt=full,nosmt mce=0 pti=on slab_nomerge=yes rng_core.default_quality=500 spec_store_bypass_disable=seccomp spectre_v2=on"

# Az alapértelmezett beállítások hozzáadása
sed -i "/^$/a $grub_params" "$TARGET/boot/grub/grubenv"

# GRUB beállítások frissítése
chroot "$TARGET" grub-mkconfig -o /boot/grub/grub.cfg

# Visszajelzés
echo "A GRUB hardening beállítások sikeresen hozzáadva. Indítás után alkalmazódnak."
exit 0
