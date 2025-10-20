#!/bin/bash
# 26_memory_exec_hardening.sh - Memória írási/futtatási jogok szigorítása (W^X elv)

echo "--- 26_memory_exec_hardening: W^X memória hardening indítása ---"

SYSCTL_FILE="/etc/sysctl.d/75-memory-hardening.conf"
CONFIG_CONTENT=""

# 1. Sysctl paraméterek listája (teljes elérési út a /proc/sys alatt: Érték)
declare -A SYSCTL_SETTINGS=(
    # ASLR és memóriaelrendezés hardening
    ["vm/mmap_rnd_bits"]=28         # Magasabb ASLR entropia (64 bites rendszereken)
    ["vm/mmap_rnd_compat_bits"]=16  # ASLR 32 bites kompatibilitáshoz
    ["vm/legacy_va_layout"]=0       # Régi (gyenge) memória elrendezés tiltása
    
    # Kritikus memória allokációs korlátozások
    ["vm/mmap_min_addr"]=65536      # NULL pointer dereference támadás elleni védelem (0x0000 cím tiltása)
    ["vm/unprivileged_userfaultfd"]=0 # Userfaultfd tiltása jogosulatlan felhasználóknak (privilege escalation ellen)
    
    # Kernel infószivárgás és viselkedés OOM esetén
    ["kernel/perf_event_paranoid"]=2 # Perf események szigorú korlátozása (Spectre védelem)
    ["fs/suid_dumpable"]=0          # Core dump szigorítás
    ["vm/panic_on_oom"]=1           # OOM esetén kernel pánik (MAX. biztonság: a bizonytalan állapot elkerülése a rendelkezésre állás rovására)
)

# 2. Sysctl változók ellenőrzése és konfigurációs fájl összeállítása
echo "2. Sysctl változók ellenőrzése a /proc/sys útvonalon..."

for VAR in "${!SYSCTL_SETTINGS[@]}"; do
    VALUE=${SYSCTL_SETTINGS[$VAR]}
    PROC_PATH="/proc/sys/$VAR"
    
    # Ellenőrzés: ha létezik a /proc/sys fájl, akkor támogatott.
    if [ -f "$PROC_PATH" ]; then
        # Hozzáadjuk a sysctl formátumot
        SYSCTL_VAR=$(echo "$VAR" | tr '/' '.')
        
        # Speciális komment a panic_on_oom-hoz
        if [ "$VAR" == "vm/panic_on_oom" ]; then
            CONFIG_CONTENT+="# vm.panic_on_oom=1: Max. biztonság: OOM esetén teljes rendszerpánik, a bizonytalan állapot elkerülése érdekében.\n"
        fi
        
        CONFIG_CONTENT+="$SYSCTL_VAR = $VALUE\n"
        echo "   -> [OK] Változó '$SYSCTL_VAR' létezik. Érték: $VALUE."
    else
        echo "   -> [KIHAGYVA] Változó '$VAR' nem található a /proc/sys alatt. Kihagyva."
    fi
done

if [ -z "$CONFIG_CONTENT" ]; then
    echo "FIGYELEM: Egyetlen hardening változó sem támogatott. Kihagyva a sysctl fájl létrehozása."
    echo "--- 26_memory_exec_hardening Befejezve (nincs módosítás) ---"
    exit 0
fi

# 3. Tranzakciós feloldás és fájl létrehozása
LOCK_STATUS=$(lsattr "$SYSCTL_FILE" 2>/dev/null | grep -o "i")

# 3a. Feloldás, ha le van zárva
if [ "$LOCK_STATUS" == "i" ]; then
    echo "3a. FIGYELEM: A $SYSCTL_FILE le van zárva. Feloldás..."
    chattr -i "$SYSCTL_FILE" 2>/dev/null
fi

# 3b. Fájl létrehozása
echo -e "$CONFIG_CONTENT" > "$SYSCTL_FILE"
echo "Sysctl fájl létrehozva: $SYSCTL_FILE"

# 4. Sysctl beállítások alkalmazása
echo "4. Sysctl beállítások azonnali alkalmazása..."
sysctl -p "$SYSCTL_FILE" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "Sikeres: Memória hardening beállítások alkalmazva."
fi

# 5. VISSZAZÁRÁS: Visszazárás, ha a fájl eredetileg le volt zárva
if [ "$LOCK_STATUS" == "i" ]; then
    echo "5. VISSZAZÁRÁS: Visszazárás, ha a fájl eredetileg le volt zárva..."
    chattr +i "$SYSCTL_FILE" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "   -> Sikeresen visszazárva (chattr +i)."
    fi
fi

echo "--- 26_memory_exec_hardening Befejezve ---"