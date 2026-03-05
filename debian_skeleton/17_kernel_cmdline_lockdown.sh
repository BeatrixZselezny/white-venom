#!/bin/bash
# 18_kernel_cmdline_lockdown.sh - Kernel indítási paraméterek szigorítása (GRUB-fókusz)

set -eu # Zero-trust: Kilépés hibánál, nem definiált változónál

GRUB_CONF="/etc/default/grub"
BACKUP_FILE="${GRUB_CONF}.bak.18"
NEW_PARAMS="lockdown=confidentiality slab_nomerge mce=0 no_timer_check pti=on vsyscall=none page_poison=1 init_on_free=1 init_on_alloc=1"

echo "--- 18_kernel_cmdline_lockdown: Kernel cmdline hardening ---"

# 1. Rollback funkció és trap
function branch_cleanup() {
 echo -e "\nKRITIKUS HIBA: Rollback indítása a(z) $GRUB_CONF fájlhoz (ACID Atomicity)..."
    
 # 1a. Visszaállítás a backupból, ha létezik
 if [ -f "$BACKUP_FILE" ]; then
 cp "$BACKUP_FILE" "$GRUB_CONF" || echo "[FIGYELEM] Nem sikerült visszaállítani a $GRUB_CONF fájlt!"
 rm -f "$BACKUP_FILE" 2>/dev/null
 echo "   -> Visszaállítás sikeres a $BACKUP_FILE fájlból."
 fi

 # 1b. Visszazárás feloldása, ha sikertelen volt a szkript
 if command -v chattr &> /dev/null && lsattr "$GRUB_CONF" 2>/dev/null | grep -q "i"; then
 chattr -i "$GRUB_CONF" || echo "[FIGYELEM] Nem sikerült feloldani a $GRUB_CONF immutability lockját!"
 echo "   -> Immunitás feloldva (chattr -i) a hibás futás miatt."
 fi
    
 # 1c. A VISSZAÁLLÍTOTT GRUB konfiguráció ÉRVÉNYESÍTÉSE (ha ez is hibázik, akkor a rendszert kézzel kell javítani)
 echo "   -> GRUB frissítés VISSZAÁLLÍTOTT konfigurációval..."
 if command -v grub-mkconfig &> /dev/null; then
 grub-mkconfig -o /boot/grub/grub.cfg || echo "[FIGYELEM] A VISSZAÁLLÍTOTT GRUB frissítése sikertelen. Kézi ellenőrzés szükséges!"
 elif command -v update-grub &> /dev/null; then
 update-grub || echo "[FIGYELEM] A VISSZAÁLLÍTOTT GRUB frissítése sikertelen. Kézi ellenőrzés szükséges!"
 fi

 exit 1
}
trap branch_cleanup ERR

# 2. Immutability Lock kezelése (FELOLDÁS)
GRUB_WAS_IMMUTABLE=0
if command -v chattr &> /dev/null; then
 if lsattr "$GRUB_CONF" 2>/dev/null | grep -q "i"; then
 GRUB_WAS_IMMUTABLE=1
 echo "2a. FIGYELEM: A $GRUB_CONF le van zárva. Feloldás..."
 chattr -i "$GRUB_CONF" # Hiba esetén (pl. jogosultság) a trap hívódik
 echo "   -> Sikeresen feloldva (chattr -i)."
 fi
fi


# 3. Ellenőrzés: Létezik-e a GRUB konfigurációs fájl
if [ ! -f "$GRUB_CONF" ]; then
    echo "Figyelem: A GRUB konfigurációs fájl ($GRUB_CONF) nem található. Létrehozzuk."
    
    # Minimális, működőképes GRUB fájltartalom létrehozása
    cat > "$GRUB_CONF" << EOF
# Ezt a fájlt a 18_kernel_cmdline_lockdown.sh script hozta létre.
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Hardened System"
GRUB_CMDLINE_LINUX=""
EOF
    echo "Létrehozva a(z) $GRUB_CONF fájl a minimális beállításokkal."
fi

# 4. Paraméterek beszúrása a GRUB_CMDLINE_LINUX_DEFAULT-ba
# Kimentjük az eredeti sort a későbbi rollbackhez (a feloldás után!)
cp "$GRUB_CONF" "$BACKUP_FILE"

if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" "$GRUB_CONF"; then
    echo "4. Frissítés: GRUB_CMDLINE_LINUX_DEFAULT módosítása..."
    
    # 4a. Eltávolítjuk a paramétereket, ha már szerepelnének a duplikáció elkerülésére
    for param in $NEW_PARAMS; do
        sed -i "s/\(GRUB_CMDLINE_LINUX_DEFAULT=.*\) $param\(.*\)/\1\2/g" "$GRUB_CONF"
    done
    
    # 4b. Beszúrjuk a teljes készletet a záró idézőjel elé, a már létező paraméterek után.
    sed -i "/GRUB_CMDLINE_LINUX_DEFAULT=/ s/\"$/ $NEW_PARAMS\"/" "$GRUB_CONF"
    
else
    # Ha a fájl létezik, de nincs benne a GRUB_CMDLINE_LINUX_DEFAULT változó, akkor hozzáadjuk a végére.
    echo "GRUB_CMDLINE_LINUX_DEFAULT változó nem található, hozzáadjuk a fájl végéhez."
    echo "GRUB_CMDLINE_LINUX_DEFAULT=\"$NEW_PARAMS\"" >> "$GRUB_CONF"
fi

echo "Sikeresen hozzáadva a következő paraméterek: $NEW_PARAMS"

# 5. GRUB konfiguráció frissítése (COMMIT)
echo "5. GRUB frissítése: grub-mkconfig futtatása (COMMIT)..."
# Ha ez hibázik, a trap hívódik és fut a rollback!
if command -v grub-mkconfig &> /dev/null; then
    grub-mkconfig -o /boot/grub/grub.cfg
    echo "GRUB konfiguráció frissítve. A változások a következő újraindításkor lépnek érvénybe."
elif command -v update-grub &> /dev/null; then
    # update-grub sok disztróban a grub-mkconfig wrapperje
    update-grub
    echo "GRUB konfiguráció frissítve (update-grub-bal). A változások a következő újraindításkor lépnek érvénybe."
else
    echo "KRITIKUS HIBA: Az 'grub-mkconfig' vagy 'update-grub' parancs nem található."
    exit 1 # Hibázunk, ami hívja a trap-et, mert a rollbacknek le kell futnia!
fi

# 6. Immutability Lock kezelése (VISSZAZÁRÁS)
if [ "$GRUB_WAS_IMMUTABLE" -eq 1 ]; then
 echo "6. VISSZAZÁRÁS: A $GRUB_CONF fájl eredetileg le volt zárva. Visszazárás..."
 chattr +i "$GRUB_CONF" # Hiba esetén (pl. jogosultság) a trap hívódik
 echo "   -> Sikeresen visszazárva (chattr +i)."
fi

rm -f "$BACKUP_FILE" 2>/dev/null # Végleges törlés

echo "--- 18_kernel_cmdline_lockdown Befejezve ---"
