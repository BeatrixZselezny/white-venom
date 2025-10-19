#!/bin/bash
# 18_kernel_cmdline_lockdown.sh - Kernel indítási paraméterek szigorítása (GRUB-fókusz)

GRUB_CONF="/etc/default/grub"
NEW_PARAMS="lockdown=confidentiality slab_nomerge mce=0 no_timer_check pti=on vsyscall=none page_poison=1 init_on_free=1 init_on_alloc=1"

echo "--- 18_kernel_cmdline_lockdown: Kernel cmdline hardening ---"

# 1. Ellenőrzés: Létezik-e a GRUB konfigurációs fájl
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

# 2. Paraméterek beszúrása a GRUB_CMDLINE_LINUX_DEFAULT-ba
# Mivel a hardening paraméterek kritikusak, a GRUB_CMDLINE_LINUX_DEFAULT-ban módosítunk/hozzáadunk.

# Kimentjük az eredeti sort a későbbi rollbackhez
cp "$GRUB_CONF" "${GRUB_CONF}.bak.18"

if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" "$GRUB_CONF"; then
    echo "Frissítés: GRUB_CMDLINE_LINUX_DEFAULT módosítása..."
    
    # 2a. Eltávolítjuk a paramétereket, ha már szerepelnének a duplikáció elkerülésére
    for param in $NEW_PARAMS; do
        sed -i "s/\(GRUB_CMDLINE_LINUX_DEFAULT=.*\) $param\(.*\)/\1\2/g" "$GRUB_CONF"
    done
    
    # 2b. Beszúrjuk a teljes készletet a záró idézőjel elé, a már létező paraméterek után.
    sed -i "/GRUB_CMDLINE_LINUX_DEFAULT=/ s/\"$/ $NEW_PARAMS\"/" "$GRUB_CONF"
    
else
    # Ha a fájl létezik, de nincs benne a GRUB_CMDLINE_LINUX_DEFAULT változó, akkor hozzáadjuk a végére.
    echo "GRUB_CMDLINE_LINUX_DEFAULT változó nem található, hozzáadjuk a fájl végéhez."
    echo "GRUB_CMDLINE_LINUX_DEFAULT=\"$NEW_PARAMS\"" >> "$GRUB_CONF"
fi

echo "Sikeresen hozzáadva a következő paraméterek: $NEW_PARAMS"

# 3. GRUB konfiguráció frissítése
echo "GRUB frissítése: grub-mkconfig futtatása..."
# Mivel a systemd ki van írtva, feltételezzük, hogy a grub-mkconfig/update-grub a helyes parancs
if command -v grub-mkconfig &> /dev/null; then
    grub-mkconfig -o /boot/grub/grub.cfg
    echo "GRUB konfiguráció frissítve. A változások a következő újraindításkor lépnek érvénybe."
elif command -v update-grub &> /dev/null; then
    # update-grub sok disztróban a grub-mkconfig wrapperje
    update-grub
    echo "GRUB konfiguráció frissítve (update-grub-bal). A változások a következő újraindításkor lépnek érvénybe."
else
    echo "KRITIKUS FIGYELEM: Az 'grub-mkconfig' vagy 'update-grub' parancs nem található."
    echo "KÉRJÜK, FRISSÍTSE A GRUB KONFIGURÁCIÓT MANUÁLISAN (pl. grub-mkconfig -o /boot/grub/grub.cfg)!"
    exit 2
fi

echo "--- 18_kernel_cmdline_lockdown Befejezve ---"
