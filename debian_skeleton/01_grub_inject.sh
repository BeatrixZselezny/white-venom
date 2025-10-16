#!/bin/bash
# Step 1 - GRUB hardware mitigation injection
# Author: Beatrix Zelezny 🐱

cd /sys/devices/system/cpu/vulnerabilities/ || exit 1

for opt in \
    "l1tf=full,force" \
    "smt=full,nosmt" \
    "spectre_v2=on" \
    "spec_store_bypass_disable=seccomp" \
    "slab_nomerge=yes" \
    "mce=0" \
    "pti=on"; do
    echo "[1] Beállítás: $opt"
    grub-editenv - set "$(grub-editenv - list | grep kernelopts) $opt"
done

echo "[1] GRUB injektálás kész."
