#!/bin/bash
# 20_pax_emulation_layer.sh - Szoftveres PaX emuláció (EXECSTACK flag javítása) patchelf-fel

echo "--- 20_pax_emulation_layer: EXECSTACK bit javítás indítása (patchelf használatával) ---"

# Ellenőrzés: A szükséges eszközök (readelf, patchelf) léteznek-e
if ! command -v readelf &> /dev/null || ! command -v patchelf &> /dev/null; then
    echo "KRITIKUS HIBA: A 'readelf' VAGY 'patchelf' parancs nem található."
    echo "Kérjük telepítse a patchelf csomagot (pl. 'sudo apt install patchelf' Debianon)."
    exit 1
fi

# Könyvtárak listája, ahol binárisokat keresünk
TARGET_DIRS="/usr/bin /usr/sbin /bin /sbin /lib /lib64 /usr/lib /usr/lib64"
FIXED_COUNT=0

# Fájlok átvizsgálása
for DIR in $TARGET_DIRS; do
    if [ -d "$DIR" ]; then
        echo "Vizsgálat indítása: $DIR könyvtárban..."
        
        # Keresés: Megtaláljuk az összes futtatható ELF fájlt.
        # Használjuk a find parancsot a lehető legszigorúbban.
        find "$DIR" -type f -perm /u=x,g=x,o=x -exec file {} + | grep 'ELF' | cut -d: -f1 | while read -r FILE; do
            
            # 1. Ellenőrzés: Az ELF fejléc tartalmaz-e futtatható stack jelzőt (X)
            # A PT_GNU_STACK mező a bejegyzés címe, ha a 4. oszlop tartalmazza az 'E' (Executable) bitet.
            
            # readelf futtatása a program headerekre, és szűrés a PT_GNU_STACK-ra.
            # Az X (eXecutable) jelzőt keressük a Flags oszlopban (pl. RWE vagy RWX, ami futtatható stackre utal).
            if readelf -l "$FILE" 2>/dev/null | grep -q "GNU_STACK" && \
               readelf -l "$FILE" 2>/dev/null | grep "GNU_STACK" | grep -q "RWE"; then
                
                echo "-> Futtatható stack (EXECSTACK/RWE) található: $FILE"
                
                # 2. Javítás: Megpróbáljuk törölni a futtatható stack flag-et
                
                # Készítünk egy backupot a zero-trust elv miatt, mielőtt módosítjuk a binárist
                cp "$FILE" "${FILE}.execstack.bak" 2>/dev/null
                
                # A patchelf --add-needed helyett a --no-execstack kapcsolót használjuk
                if patchelf --set-flags "no-execstack" "$FILE"; then
                    echo "   -> Sikeresen javítva (patchelf --set-flags no-execstack)."
                    FIXED_COUNT=$((FIXED_COUNT + 1))
                else
                    echo "   -> Hiba a javítás során (pl. jogosultság vagy már lezárt fájl). Kihagyás."
                    # Visszaállítjuk a backupot, ha a javítás sikertelen volt
                    mv "${FILE}.execstack.bak" "$FILE" 2>/dev/null
                fi
            fi
        done
    fi
done

echo "--- 20_pax_emulation_layer Befejezve ---"
echo "Összesen javított binárisok száma: $FIXED_COUNT."
