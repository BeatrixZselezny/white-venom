#!/bin/bash
# 22_mount_opts_hardening.sh - Kritikus mountolási opciók szigorítása az /etc/fstab-ban

**set -eu** # Zero-trust: Kilépés hibánál, nem definiált változónál

echo "--- 22_mount_opts_hardening: Fájlrendszer hardening indítása (/etc/fstab) ---"

FSTAB_FILE="/etc/fstab"
BACKUP_FILE="${FSTAB_FILE}.bak.22"

**# Rollback funkció: Hiba esetén visszaállítja a backupot és feloldja az fstab-ot**
**function branch_cleanup() {**
** echo -e "\nKRITIKUS HIBA: Rollback indítása a(z) $FSTAB_FILE fájlhoz..."**
    
** # 1. Visszaállítás a backupból, ha létezik**
** if [ -f "$BACKUP_FILE" ]; then**
** cp "$BACKUP_FILE" "$FSTAB_FILE" || echo "[FIGYELEM] Nem sikerült visszaállítani a $FSTAB_FILE-t!"**
** rm -f "$BACKUP_FILE" 2>/dev/null**
** echo "   -> Visszaállítás sikeres a $BACKUP_FILE fájlból."**
** fi**

** # 2. Visszazárás feloldása, ha sikertelen volt a szkript (hogy a felhasználó tudjon dolgozni)**
** if command -v chattr &> /dev/null && lsattr "$FSTAB_FILE" 2>/dev/null | grep -q "i"; then**
** chattr -i "$FSTAB_FILE" || echo "[FIGYELEM] Nem sikerült feloldani a $FSTAB_FILE immutability lockját!"**
** echo "   -> Immunitás feloldva (chattr -i) a hibás futás miatt."**
** fi**

** exit 1**
**}**
**trap branch_cleanup ERR**

# 1. Ellenőrzés és biztonsági mentés
if [ ! -f "$FSTAB_FILE" ]; then
    echo "KRITIKUS HIBA: A $FSTAB_FILE fájl nem található. Kihagyás."
    exit 1
fi

**# 1a. Visszazárás feloldása, ha korábban (pl. 23. szkript) lezárta**
**if command -v chattr &> /dev/null && lsattr "$FSTAB_FILE" 2>/dev/null | grep -q "i"; then**
** echo "FIGYELEM: A $FSTAB_FILE le van zárva. Feloldás..."**
** chattr -i "$FSTAB_FILE" # chattr hiba esetén set -e / trap branch_cleanup hívódik**
** echo "   -> Sikeresen feloldva (chattr -i)."**
**fi**

cp "$FSTAB_FILE" "${FSTAB_FILE}.bak.22"
echo "Biztonsági mentés létrehozva: ${FSTAB_FILE}.bak.22"

# 2. Hardening szabályok meghatározása (Mount pont: Kötelező opciók)
declare -A HARDENING_RULES=(
    ["/tmp"]="noexec,nosuid,nodev"
    ["/var/tmp"]="noexec,nosuid,nodev"
    ["/home"]="nodev"
    ["/boot"]="noexec,nodev"
    ["/proc"]="hidepid=2" # ÚJ SZABÁLY: A felhasználói folyamatinfó elrejtése
)

# 3. /etc/fstab frissítése az AWK-val (Robusztus oszlopmódosítás)
TEMP_FSTAB=$(mktemp)
FSTAB_MODIFIED=0

awk '
    BEGIN {
        # Az AWK asszociatív tömbje a szabályoknak
        RULES["/tmp"] = "noexec,nosuid,nodev"
        RULES["/var/tmp"] = "noexec,nosuid,nodev"
        RULES["/home"] = "nodev"
        RULES["/boot"] = "noexec,nodev"
        RULES["/proc"] = "defaults,hidepid=2" 
    }

    $1 !~ /^#/ && NF >= 6 {
        MOUNT_POINT = $2
        **FS_TYPE = $3 # Fájlrendszer típus a proc/null checkhez**
        if (MOUNT_POINT in RULES) {
            
            # **Finomított logika: /proc esetén ellenőrizzük, hogy valóban "proc" típusú-e**
            **if (MOUNT_POINT == "/proc" && FS_TYPE != "proc") {**
                **print; next # Kihagyjuk, ha nem proc típusú a /proc mount pont**
            **}**
            
            # Megtaláltuk a módosítandó sort
            NEW_OPTS_LIST = ""
            TARGET_OPTS = RULES[MOUNT_POINT]
            
            # Szétválasztjuk a régi opciókat
            split($4, OLD_OPTS, ",")
            
            # Összegyűjtjük a meglévő, nem ütköző opciókat
            for (i in OLD_OPTS) {
                OPT = OLD_OPTS[i]
                # Kizárjuk az exec/suid/dev gyengítő opciókat
                if (OPT == "exec" || OPT == "suid" || OPT == "dev" || OPT == "hidepid=0" || OPT == "hidepid=1") {
                    continue
                } 
                
                # Ha az opció nem üres, és nem ismétlődik (később ellenőrizzük)
                if (OPT != "") {
                    if (NEW_OPTS_LIST != "") NEW_OPTS_LIST = NEW_OPTS_LIST ","
                    NEW_OPTS_LIST = NEW_OPTS_LIST OPT
                }
            }
            
            # Hozzáadjuk a kötelező hardening opciókat, elkerülve a duplikációt
            split(TARGET_OPTS, REQUIRED_OPTS, ",")
            for (i in REQUIRED_OPTS) {
                OPT = REQUIRED_OPTS[i]
                # Egyszerű ellenőrzés duplikáció ellen
                if (index(NEW_OPTS_LIST, OPT) == 0) {
                    if (NEW_OPTS_LIST != "") NEW_OPTS_LIST = NEW_OPTS_LIST ","
                    NEW_OPTS_LIST = NEW_OPTS_LIST OPT
                }
            }
            
            # Összefűzzük az új sort és kinyomtatjuk
            $4 = NEW_OPTS_LIST
            print
            MODIFIED = 1
            next
        }
    }
    
    # Minden más sor kinyomtatása változatlanul
    { print }
    
    END {
        if (MODIFIED) {
            print "### FSTAB_MODIFIED_FLAG_SET ###" > "/dev/stderr" 
        }
    }

' "$FSTAB_FILE" > "$TEMP_FSTAB"

# Végleges felülírás és hibajelzés
if grep -q "### FSTAB_MODIFIED_FLAG_SET ###" "$TEMP_FSTAB"; then
    FSTAB_MODIFIED=1
    grep -v "### FSTAB_MODIFIED_FLAG_SET ###" "$TEMP_FSTAB" > "$FSTAB_FILE"
    echo "Sikeres: Az $FSTAB_FILE fájl módosítva."
else
    # Ha nem volt módosítás (pl. a proc bejegyzés nem proc típusú volt, vagy már megfelelő)
    **# Megtartjuk a régi tartalmat, de töröljük a felesleges backupot, ha nem módosult semmi**
    rm -f "$BACKUP_FILE" 2>/dev/null
    mv "$TEMP_FSTAB" "$FSTAB_FILE" 
    echo "Figyelem: A megcélzott mount pontok egyike sem került módosításra vagy nem található az fstab-ban."
    **# Nem csinálunk semmit a lock-kal, ha nem volt módosítás.**
    **exit 0**
fi

rm -f "$TEMP_FSTAB" 2>/dev/null


# 4. Újra-mountolás az azonnali érvényesítéshez (Auditálás!)
echo "4. Mount pontok azonnali újracsatolása (re-mount)..."
for MOUNT_POINT in "${!HARDENING_RULES[@]}"; do
    if grep -q "^[^#].*\s$MOUNT_POINT\s" "$FSTAB_FILE"; then
        # Remountoljuk a fájlrendszert
        **mount -o remount "$MOUNT_POINT" # Eltávolítva a 2>/dev/null!**
        
        # Auditálás: Ellenőrizzük, hogy a kulcsopciók sikeresen aktiválódtak-e
        OPTS_TO_CHECK=""
        if [[ "$MOUNT_POINT" == "/proc" ]]; then
            OPTS_TO_CHECK="hidepid=2"
        else
            OPTS_TO_CHECK="noexec"
        fi
        
        if findmnt --target "$MOUNT_POINT" -n -o OPTIONS **| grep -qE "(^|,)$OPTS_TO_CHECK(,|$)"; then # Hiba elnyelés eltávolítva**
            echo "   -> Sikeres ellenőrzés: $MOUNT_POINT opciók ($OPTS_TO_CHECK) érvényben."
        else
            echo "   -> KRITIKUS HIBA: $MOUNT_POINT opciók ellenőrzése sikertelen. Kilépés a Rollbackhez."
            **exit 1 # A set -e / trap hívódik**
        fi
    fi
done

**# 5. Sikeres futás: Fájl lezárása**
**if command -v chattr &> /dev/null; then**
** chattr +i "$FSTAB_FILE" # chattr hiba esetén set -e / trap branch_cleanup hívódik**
** echo "5. Sikeresen lezárva: $FSTAB_FILE (chattr +i)."**
**fi**

rm -f "$BACKUP_FILE" 2>/dev/null # Végleges törlés

echo "--- 22_mount_opts_hardening Befejezve ---"
