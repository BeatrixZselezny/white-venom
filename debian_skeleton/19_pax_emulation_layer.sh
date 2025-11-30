#!/bin/bash
# 20_pax_emulation_layer.sh - Szoftveres PaX emuláció (EXECSTACK flag javítása) patchelf-fel

**set -euo pipefail** # Zero-trust: Kilépés hibánál, nem definiált változónál

echo "--- 20_pax_emulation_layer: EXECSTACK bit javítás indítása (patchelf használatával) ---"

# --- TRANZAKCIÓS TISZTÍTÁS (ROLLBACK) ---
**# JAVÍTÁS: A rollback funkció most minden érintett fájlt visszaállít és törli a felesleges backupot.**
function branch_cleanup() {
    echo -e "\n[CRITICAL ALERT] Hiba történt a 20-as ág futása közben! Megkísérlem a rollbacket..."
    
    # Keresés az összes létrehozott .execstack.bak fájlra
    find /usr /bin /sbin /lib /lib64 -type f -name "*.execstack.bak" 2>/dev/null | while read -r BACKUP_FILE; do
        ORIGINAL_FILE="${BACKUP_FILE%.execstack.bak}"
        echo "   -> Visszaállítás: $ORIGINAL_FILE a $BACKUP_FILE fájlból."
        
        # Visszaállítja a binárist
        mv "$BACKUP_FILE" "$ORIGINAL_FILE" || echo "[FIGYELEM] Nem sikerült visszaállítani a $ORIGINAL_FILE fájlt!"
        
        # Ha eredetileg le volt zárva, feloldjuk, majd visszaállítjuk, ha a hiba előtt fel lett oldva
        if command -v chattr &> /dev/null; then
            if lsattr "$ORIGINAL_FILE" 2>/dev/null | grep -q "i"; then
                chattr -i "$ORIGINAL_FILE" 2>/dev/null # Rollback alatt is lehet, hogy le volt zárva a hiba előtt
            fi
        fi
        
    done
    echo "[CRITICAL ALERT] 20-as ág rollback befejezve. Kézi ellenőrzés szükséges!"
    exit 1
}
trap branch_cleanup ERR

# Ellenőrzés: A szükséges eszközök (readelf, patchelf) léteznek-e
if ! command -v readelf &> /dev/null || ! command -v patchelf &> /dev/null; then
    echo "KRITIKUS HIBA: A 'readelf' VAGY 'patchelf' parancs nem található."
    exit 1
fi
if ! command -v chattr &> /dev/null; then
    echo "FIGYELEM: A 'chattr' parancs nem található. Az immutability lock kezelése nem lehetséges."
fi


# Könyvtárak listája, ahol binárisokat keresünk
TARGET_DIRS="/usr/bin /usr/sbin /bin /sbin /lib /lib64 /usr/lib /usr/lib64"
FIXED_COUNT=0

# Fájlok átvizsgálása
for DIR in $TARGET_DIRS; do
    if [ -d "$DIR" ]; then
        echo "Vizsgálat indítása: $DIR könyvtárban..."
        
        # Keresés: Megtaláljuk az összes futtatható ELF fájlt.
        # **JAVÍTÁS: A find + file + grep logikát megtartjuk, de továbbfejlesztjük.**
        find "$DIR" -type f -perm /u=x,g=x,o=x -exec file {} + | grep 'ELF' | cut -d: -f1 | while read -r FILE; do
            
            # **JAVÍTÁS: Egyszerűsített readelf logika:**
            # A PT_GNU_STACK-ot keressük, ahol az X (eXecutable) bit van a Flags oszlopban.
            # Használjuk az AWK-t a hatékonyabb oszlop alapú kereséshez.
            if readelf -l "$FILE" 2>/dev/null | awk '/GNU_STACK/ { if (substr($NF, 1, 1) == "R" && index($NF, "X")) { print } }' | grep -q "GNU_STACK"; then
                
                echo "-> Futtatható stack (EXECSTACK/RWE) található: $FILE"
                
                # --- IMMUTABILITY LOCK KEZELÉSE ---
                **WAS_IMMUTABLE=0**
                **if command -v chattr &> /dev/null && lsattr "$FILE" 2>/dev/null | grep -q "i"; then**
                ** WAS_IMMUTABLE=1**
                ** echo "   -> LOCK: Fájl le van zárva. Feloldás (chattr -i)..."**
                ** chattr -i "$FILE" # Set -e hibázik, ha nincs jogosultság -> TRAP**
                **fi**

                # 2. Javítás: Megpróbáljuk törölni a futtatható stack flag-et
                
                # Készítünk egy backupot a zero-trust elv miatt
                cp "$FILE" "${FILE}.execstack.bak"
                
                # A patchelf --no-execstack kapcsolót használjuk
                if patchelf --set-flags "no-execstack" "$FILE"; then
                    echo "   -> Sikeresen javítva (patchelf --set-flags no-execstack)."
                    FIXED_COUNT=$((FIXED_COUNT + 1))
                    
                    # **JAVÍTÁS: Sikeres javítás után töröljük a backupot (COMMIT)**
                    rm -f "${FILE}.execstack.bak"
                    
                else
                    echo "   -> Hiba a javítás során. Visszaállítás a backupból."
                    # Visszaállítjuk a backupot, ha a javítás sikertelen volt
                    mv "${FILE}.execstack.bak" "$FILE"
                fi

                # --- VISSZAZÁRÁS ---
                **if [ "$WAS_IMMUTABLE" -eq 1 ]; then**
                ** echo "   -> LOCK: Visszazárás (chattr +i)..."**
                ** chattr +i "$FILE" # Set -e hibázik, ha nincs jogosultság -> TRAP**
                **fi**
            fi
        done
    fi
done

echo "--- 20_pax_emulation_layer Befejezve ---"
echo "Összesen javított binárisok száma: $FIXED_COUNT."
