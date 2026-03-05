#!/bin/bash

# Pre-upgrade előkészítő script a White Venom rendszerhez
# Cél: chattr +i flagek eltávolítása upgrade előtt

set -e

# -- Ellenőrizzük a jogosultságokat --
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: A szkriptet rootként kell futtatni (sudo-val)."
    exit 1
fi

echo "[pre-upgrade] White Venom pre-upgrade indul..."

# -- Célfájlok (később bővíthető) --
LDCONF="/etc/ld.so.conf.d/skell.conf"
LIB_DIRS=("/usr/lib" "/lib" "/usr/local/lib")

# -- chattr -i LDCONF fájl --
if [ -f "$LDCONF" ]; then
    echo "[pre-upgrade] chattr -i: $LDCONF"
    chattr -i "$LDCONF" || true
fi

# -- chattr -i minden .so fájlra a megadott könyvtárakban --
for dir in "${LIB_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "[pre-upgrade] Feldolgozás: $dir"
        find "$dir" -type f -name '*.so*' -exec chattr -i {} \; 2>/dev/null || true
    fi
done

echo "[pre-upgrade] chattr +i eltávolítva. Futtatható a frissítés."
exit 0
