#!/bin/bash
# 21_ptrace_lockdown.sh - Ptrace és dinamikus linker korlátozása

echo "--- 21_ptrace_lockdown: Ptrace és LD_PRELOAD lockdown indítása ---"

# 1. Ptrace korlátozás beállítása a kernelben (kernel.yama.ptrace_scope)

# A korábbi megbeszélés alapján a legszigorúbb, de még kezelhető értéket választjuk.
# 2 = Csak a root hívhatja a ptrace-t (minden más folyamat számára tiltott)
PTRACE_SCOPE_VALUE=2

SYSCTL_FILE="/etc/sysctl.d/70-ptrace-lockdown.conf"

echo "1. kernel.yama.ptrace_scope beállítása $PTRACE_SCOPE_VALUE-re (csak root ptrace engedélyezett)..."

# Létrehozzuk a sysctl fájlt a ptrace korlátozáshoz
cat > "$SYSCTL_FILE" << EOF
# Ptrace korlátozása (Yama security module)
# 1 = Csak a szülő és a gyerek folyamatok vizsgálhatják egymást (standard hardening)
# 2 = Csak a root hívhatja a ptrace-t (zero-trust, legszigorúbb)
kernel.yama.ptrace_scope = $PTRACE_SCOPE_VALUE
EOF

# Alkalmazzuk azonnal a beállítást és ellenőrizzük a hibát
sysctl -p "$SYSCTL_FILE" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "Sikeres: kernel.yama.ptrace_scope beállítva."
else
    # Ha a sysctl parancs futott, de a beállítás nem érvényesült, a Yama LSM hiányzik.
    echo "FIGYELEM: A sysctl alkalmazása nem sikerült. Lehetséges, hogy a Yama LSM nincs engedélyezve a kernelben."
fi

# Auditálás: Ellenőrizzük, hogy mi az aktuális érték
ACTUAL_SCOPE=$(cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null)
if [ "$ACTUAL_SCOPE" == "$PTRACE_SCOPE_VALUE" ]; then
    echo "Audit: A ptrace_scope jelenleg $ACTUAL_SCOPE. Sikeres."
elif [ -n "$ACTUAL_SCOPE" ]; then
    echo "Audit: A ptrace_scope jelenleg $ACTUAL_SCOPE. A beállított érték: $PTRACE_SCOPE_VALUE."
else
    echo "Audit: /proc/sys/kernel/yama/ptrace_scope nem található. Yama valószínűleg nem fut."
fi


# 2. Dinamikus linker manipuláció korlátozása (LD_PRELOAD)

LD_SO_PRELOAD="/etc/ld.so.preload"

# 2a. ld.so.preload fájl szigorú jogosultság beállítása (ha létezik)
if [ -f "$LD_SO_PRELOAD" ]; then
    echo "2a. LD_SO_PRELOAD jogosultságok szigorítása..."
    
    # A fájlt csak a root olvashatja/írhatja
    chmod 600 "$LD_SO_PRELOAD"
    chown root:root "$LD_SO_PRELOAD"
    echo "Sikeres: $LD_SO_PRELOAD jogosultsága 600-ra szigorítva."
    
    # EMLÉKEZTETŐ a 23. lépésre
    echo "Emlékeztető: A $LD_SO_PRELOAD fájlra a 23. lépésben 'chattr +i' védelem lesz alkalmazva."
fi

# 2b. ld.so.cache fájlok jogosultságának ellenőrzése
# Ezek a fájlok listázzák a megosztott könyvtárakat, és létfontosságúak az LD_PRELOAD támadások ellen.
echo "2b. ld.so.cache fájlok jogosultságának ellenőrzése..."
find /etc /var /lib -name "ld.so.cache" -exec chmod 644 {} \;
find /etc /var /lib -name "ld.so.cache" -exec chown root:root {} \;
echo "Sikeres: ld.so.cache fájlok jogosultsága 644-re és root tulajdonosra állítva."


echo "--- 21_ptrace_lockdown Befejezve ---"
