#!/bin/bash

# Ellenőrizzük, hogy melyik editenv elérhető
if command -v grub2-editenv &> /dev/null; then
    GRUB_EDITENV="grub2-editenv"
elif command -v grub-editenv &> /dev/null; then
    GRUB_EDITENV="grub-editenv"
else
    echo "Grub editenv parancs nem található! Kérjük, telepítse a grub2 vagy grub csomagot."
    exit 1
fi

# Mitigációs paraméterek, alapértelmezett értékek
KERNEL_OPTS=""
SMT_OPTS="smt=full,nosmt"
GRUB_OPTIONS=""

# Sérülékenységek ellenőrzése a /sys/devices/system/cpu/vulnerabilities könyvtárban
echo "CPU sérülékenységek ellenőrzése..."

# Mitigációk beállítása a sérülékenységek alapján
if [ -f /sys/devices/system/cpu/vulnerabilities/spectre_v2 ]; then
    SPECTRE_V2=$(cat /sys/devices/system/cpu/vulnerabilities/spectre_v2)
    if [[ "$SPECTRE_V2" == *"Vulnerable"* ]]; then
        KERNEL_OPTS+=" spectre_v2=on"
    fi
fi

if [ -f /sys/devices/system/cpu/vulnerabilities/spectre_v1 ]; then
    SPECTRE_V1=$(cat /sys/devices/system/cpu/vulnerabilities/spectre_v1)
    if [[ "$SPECTRE_V1" == *"Vulnerable"* ]]; then
        KERNEL_OPTS+=" spectre_v1=on"
    fi
fi

if [ -f /sys/devices/system/cpu/vulnerabilities/meltdown ]; then
    MELTDOWN=$(cat /sys/devices/system/cpu/vulnerabilities/meltdown)
    if [[ "$MELTDOWN" == *"Vulnerable"* ]]; then
        KERNEL_OPTS+=" meltdown=on"
    fi
fi

if [ -f /sys/devices/system/cpu/vulnerabilities/l1tf ]; then
    L1TF=$(cat /sys/devices/system/cpu/vulnerabilities/l1tf)
    if [[ "$L1TF" == *"Vulnerable"* ]]; then
        KERNEL_OPTS+=" l1tf=full,force"
    fi
fi

if [ -f /sys/devices/system/cpu/vulnerabilities/mds ]; then
    MDS=$(cat /sys/devices/system/cpu/vulnerabilities/mds)
    if [[ "$MDS" == *"Vulnerable"* ]]; then
        KERNEL_OPTS+=" mds=full,force"
    fi
fi

if [ -f /sys/devices/system/cpu/vulnerabilities/retbleed ]; then
    RETBLEED=$(cat /sys/devices/system/cpu/vulnerabilities/retbleed)
    if [[ "$RETBLEED" == *"Vulnerable"* ]]; then
        KERNEL_OPTS+=" retbleed=on"
    fi
fi

# GRUB környezet beállítása
echo "A következő környezeti változókat állítjuk be:"
echo "KERNEL_OPTS: $KERNEL_OPTS"
echo "SMT_OPTS: $SMT_OPTS"

# A kernel paraméterek alkalmazása a grub környezetbe
$GRUB_EDITENV - set "$(grub-editenv - list | grep kernelopts) $KERNEL_OPTS"
$GRUB_EDITENV - set "$(grub-editenv - list | grep kernelopts) $SMT_OPTS"

# GRUB frissítése
echo "Frissítjük a GRUB-ot a módosítások alkalmazásához..."
update-grub

echo "GRUB frissítése kész. A rendszer újraindításával alkalmazhatók a változtatások."
