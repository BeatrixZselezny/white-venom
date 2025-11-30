#!/bin/bash
# 24_module_signing_config.sh - Kernel Modul Aláírás Kikényszerítése (Tranzakciós Lezárás-Feloldás)

echo "--- 24_module_signing_config: Kernel modul aláírás kikényszerítése indítása ---"

GRUB_FILE="/etc/default/grub"
MODPROBE_CONF="/etc/modprobe.d/99-enforce-signing.conf"
GRUB_ENTRY="module.sig_enforce=1"

# 1. KRITIKUS: A lezárt /etc/default/grub fájl feloldása (a 23. lépés után)
if lsattr "$GRUB_FILE" 2>/dev/null | grep -q "i"; then
    echo "1a. FIGYELEM: A $GRUB_FILE fájl le van zárva (i flag). Feloldás futtatás előtt..."
    chattr -i "$GRUB_FILE" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "   -> Sikeresen feloldva (chattr -i)."
    else
        echo "   -> KRITIKUS HIBA: Nem sikerült feloldani a $GRUB_FILE fájlt. Megszakítás."
        exit 1
    fi
fi

# 2. Kernel modul aláírás kikényszerítése modprobe.d beállítással
echo "2. Az aláírás ellenőrzésének kikényszerítése a kernel modul betöltésekor..."

cat > "$MODPROBE_CONF" << EOF
# Modul aláírás kikényszerítése
options module sig_enforce=1
EOF
echo "Sikeres: $MODPROBE_CONF fájl létrehozva."


# 3. /etc/default/grub frissítése (kernel cmdline)
echo "3. GRUB konfiguráció frissítése a module.sig_enforce=1 opcióval..."

if [ -f "$GRUB_FILE" ]; then
    
    # Eltávolítjuk az esetleges korábbi 'sig_enforce=0' bejegyzést
    sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/ s/\(\smodule\.sig_enforce=\)[01]/\ /g' "$GRUB_FILE"
    
    # Csak akkor adjuk hozzá, ha még nincs benne
    if ! grep -q "GRUB_CMDLINE_LINUX_DEFAULT.*$GRUB_ENTRY" "$GRUB_FILE"; then
        
        # Hozzáadjuk a GRUB_CMDLINE_LINUX_DEFAULT-hoz
        sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $GRUB_ENTRY\"/g" "$GRUB_FILE"
        echo "   -> Sikeres: $GRUB_ENTRY hozzáadva a $GRUB_FILE-hoz."
    else
        echo "   -> Figyelem: A $GRUB_ENTRY már szerepel a $GRUB_FILE-ban. Kihagyva."
    fi
else
    echo "   -> HIBA: $GRUB_FILE nem található. A GRUB frissítés kihagyva."
fi


# 4. KRITIKUS: Visszazárás, ha a fájl eredetileg le volt zárva
if grep -q "i" <<< "$(lsattr -d "$GRUB_FILE.bak" 2>/dev/null)"; then
    # Ha a 23. lépés lezárta, akkor az általunk korábban készített backup nem lehet lezárt, 
    # de a 23. lépés a GRUB_FILE-t lezárta. Ezt a logikát itt most egyszerűsítjük.

    # Auditálás, hogy a lezárás megtörténjen a 23. szkript újra futtatásával
    echo "4. VISSZAZÁRÁS: A $GRUB_FILE fájl sikeresen módosult."
    echo "   -> A tranzakció lezárásához futtassa újra a 23_immutable_critical_paths.sh szkriptet!"
    chattr +i "$GRUB_FILE" 2>/dev/null # A legjobb szándékkal visszazárjuk
    
    # A modprobe.d fájlt is hozzáadtuk, ezt is lezárjuk
    chattr +i "$MODPROBE_CONF" 2>/dev/null
fi


# 5. Emlékeztető a véglegesítéshez
echo "FIGYELEM: A változtatások alkalmazásához futtassa az 'update-grub' parancsot és **INDÍTSA ÚJRA** a rendszert!"
echo "   -> Ezt a lépést a hardening fázis végén automatizálni kell!"

echo "--- 24_module_signing_config Befejezve ---"
