#!/bin/bash
# 26_memory_exec_hardening.sh - Memória írási/futtatási jogok szigorítása (W^X elv)

echo "--- 26_memory_exec_hardening: W^X memória hardening indítása ---"

SYSCTL_FILE="/etc/sysctl.d/75-memory-hardening.conf"

# Sysctl paraméterek listája (változó=érték)
declare -A SYSCTL_SETTINGS=(
    ["vm.mmap_rnd_bits"]=28
    ["vm.mmap_rnd_compat_bits"]=16
    ["vm.legacy_va_layout"]=0
    ["kernel.perf_event_paranoid"]=2
    ["fs.suid_dumpable"]=0
)

# 1. Sysctl változók létezésének ellenőrzése
CONFIG_CONTENT=""
echo "1. Sysctl változók ellenőrzése és konfigurációs fájl összeállítása..."

for VAR in "${!SYSCTL_SETTINGS[@]}"; do
    VALUE=${SYSCTL_SETTINGS[$VAR]}
    
    # Ellenőrizzük, hogy a sysctl parancs ismeri-e a változót
    if sysctl -n "$VAR" &> /dev/null; then
        echo "   -> [OK] Változó '$VAR' létezik. Érték: $VALUE."
        CONFIG_CONTENT+="# $VAR beállítva $VALUE-ra (26. lépés)\n"
        CONFIG_CONTENT+="$VAR = $VALUE\n"
    else
        echo "   -> [KIHAGYVA] Változó '$VAR' NEM létezik a kernelben. Kihagyva."
    fi
done

if [ -z "$CONFIG_CONTENT" ]; then
    echo "FIGYELEM: Egyetlen hardening változó sem támogatott. Kihagyva a sysctl fájl létrehozása."
    echo "--- 26_memory_exec_hardening Befejezve (nincs módosítás) ---"
    exit 0
fi

# 2. Sysctl fájl létrehozása és Visszazárási logikára való felkészülés
LOCK_STATUS=$(lsattr "$SYSCTL_FILE" 2>/dev/null | grep -o "i")

# 2a. Feloldás, ha le van zárva
if [ "$LOCK_STATUS" == "i" ]; then
    echo "2a. FIGYELEM: A $SYSCTL_FILE le van zárva. Feloldás..."
    chattr -i "$SYSCTL_FILE" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "   -> KRITIKUS HIBA: Nem sikerült feloldani a sysctl fájlt. Megszakítás."
        exit 1
    fi
fi

# 2b. Fájl létrehozása (a $CONFIG_CONTENT használatával)
echo -e "$CONFIG_CONTENT" > "$SYSCTL_FILE"
echo "Sysctl fájl létrehozva: $SYSCTL_FILE"

# 3. Sysctl beállítások alkalmazása
echo "3. Sysctl beállítások azonnali alkalmazása..."
sysctl -p "$SYSCTL_FILE" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "Sikeres: Memória hardening beállítások alkalmazva."
else
    echo "FIGYELEM: A sysctl alkalmazása sikertelen. Kézi ellenőrzés szükséges."
fi

# 4. VISSZAZÁRÁS: Visszazárás, ha a fájl eredetileg le volt zárva
if [ "$LOCK_STATUS" == "i" ]; then
    echo "4. VISSZAZÁRÁS: A sysctl fájl eredetileg le volt zárva. Visszazárás..."
    chattr +i "$SYSCTL_FILE" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "   -> Sikeresen visszazárva (chattr +i)."
    else
        echo "   -> FIGYELEM: A visszazárás sikertelen."
    fi
fi

echo "--- 26_memory_exec_hardening Befejezve ---"