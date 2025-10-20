#!/bin/bash
# 22_mount_opts_hardening.sh - Kritikus mountolási opciók szigorítása az /etc/fstab-ban

echo "--- 22_mount_opts_hardening: Fájlrendszer hardening indítása (/etc/fstab) ---"

FSTAB_FILE="/etc/fstab"

# 1. Ellenőrzés és biztonsági mentés
if [ ! -f "$FSTAB_FILE" ]; then
    echo "KRITIKUS HIBA: A $FSTAB_FILE fájl nem található. Kihagyás."
    exit 1
fi

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
        RULES["/proc"] = "defaults,hidepid=2" # A /proc-hoz a "defaults" is kellhet
    }

    $1 !~ /^#/ && NF >= 6 {
        MOUNT_POINT = $2
        if (MOUNT_POINT in RULES) {
            
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
    mv "$TEMP_FSTAB" "$FSTAB_FILE" 
    echo "Figyelem: A megcélzott mount pontok egyike sem került módosításra vagy nem található az fstab-ban."
fi

rm -f "$TEMP_FSTAB" 2>/dev/null


# 4. Újra-mountolás az azonnali érvényesítéshez (Auditálás!)
echo "4. Mount pontok azonnali újracsatolása (re-mount)..."
for MOUNT_POINT in "${!HARDENING_RULES[@]}"; do
    if grep -q "^[^#].*\s$MOUNT_POINT\s" "$FSTAB_FILE"; then
        # Remountoljuk a fájlrendszert
        mount -o remount "$MOUNT_POINT" 2>/dev/null
        
        # Auditálás: Ellenőrizzük, hogy a kulcsopciók sikeresen aktiválódtak-e
        OPTS_TO_CHECK=""
        if [[ "$MOUNT_POINT" == "/proc" ]]; then
            OPTS_TO_CHECK="hidepid=2"
        else
            OPTS_TO_CHECK="noexec"
        fi
        
        if findmnt --target "$MOUNT_POINT" -n -o OPTIONS 2>/dev/null | grep -qE "(^|,)$OPTS_TO_CHECK(,|$)"; then
            echo "   -> Sikeres ellenőrzés: $MOUNT_POINT opciók ($OPTS_TO_CHECK) érvényben."
        else
            echo "   -> FIGYELEM: $MOUNT_POINT opciók ellenőrzése sikertelen. Kérem indítsa újra a rendszert a teljes érvényesítéshez!"
        fi
    fi
done

echo "--- 22_mount_opts_hardening Befejezve ---"
