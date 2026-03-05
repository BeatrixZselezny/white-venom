#!/bin/bash
# 23_immutable_critical_paths.sh - Kritikus útvonalak és fájlok logikai lezárása (chattr +i)

echo "--- 23_immutable_critical_paths: Logikai fájlvédelem indítása (chattr +i) ---"

# 1. Ellenőrzés: A chattr parancs elérhetősége
if ! command -v chattr &> /dev/null; then
    echo "KRITIKUS HIBA: A 'chattr' parancs nem található. (Általában a 'e2fsprogs' csomag része)."
    exit 1
fi

# 2. Kritikus fájlok listája a hardening terv alapján
# Ezeket a fájlokat módosítottuk az elmúlt lépésekben:
# 17. lépés: Kernel modul blacklist
# 18. lépés: Kernel cmdline lockdown
# 19. lépés: Build környezet CFLAGS/CXXFLAGS
# 21. lépés: Ptrace lockdown és linker
# 22. lépés: Mount opciók hardening
CRITICAL_FILES=(
    # Boot/Kernel konfigurációk
    "/etc/default/grub"               # 18. lépés (Kernel cmdline)
    "/etc/modprobe.d/blacklist.conf"  # 17. lépés (Kernel modul blacklist)
    "/etc/sysctl.d/70-ptrace-lockdown.conf" # 21. lépés (Ptrace scope)
    "/etc/sysctl.d/90-hardening.conf" # A hardening sysctl fájl (amit korábban/később generálunk)

    # Dinamikus linker védelem (21. lépés megerősítése)
    "/etc/ld.so.preload"              # Dinamikus linker manipuláció ellen
    "/etc/ld.so.conf"                 # Linker fő konfiguráció
    "/etc/ld.so.conf.d"               # Linker konfigurációs könyvtár

    # Fájlrendszer/Rendszer konfigurációk
    "/etc/fstab"                      # 22. lépés (Mount opciók)
    "/etc/passwd"                     # Felhasználói adatbázis
    "/etc/shadow"                     # Jelszó hash-ek
    "/etc/group"                      # Csoport adatbázis
    "/etc/sudoers"                    # Sudo konfiguráció

    # Hálózati konfigurációk
    "/etc/network/interfaces"         # Hálózati interface definíciók
    "/etc/resolv.conf"                # DNS resolver
    "/etc/hosts"                      # DNS statikus feloldások
)

# 3. Chattr +i attribútum alkalmazása
echo "2. Chattr +i attribútum alkalmazása a kritikus fájlokra..."
for FILE in "${CRITICAL_FILES[@]}"; do
    if [ -e "$FILE" ]; then
        # -V: verbose, +i: immutable
        chattr +i "$FILE" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "   -> Lezárva: $FILE (chattr +i)"
        else
            echo "   -> FIGYELEM: $FILE lezárása sikertelen. (Lehetséges, hogy a fájlrendszer nem támogatja, pl. tmpfs, vagy ext3/4 hiányzik)."
        fi
    else
        echo "   -> Kihagyva: $FILE nem létezik. (Ez rendben van, ha a fájl még nem lett létrehozva)."
    fi
done

# 4. Auditálás: Lezárt fájlok ellenőrzése
echo "3. Auditálás: Lezárt fájlok ellenőrzése (lsattr)..."
for FILE in "${CRITICAL_FILES[@]}"; do
    if [ -e "$FILE" ]; then
        if lsattr -d "$FILE" 2>/dev/null | grep -q "i"; then
            : # Sikeres, nem logolunk zöld utat, hogy rövid maradjon a kimenet
        else
            echo "   -> HIBA: $FILE nem tartalmazza az 'i' (immutable) flag-et!"
        fi
    fi
done

echo "--- 23_immutable_critical_paths Befejezve ---"
echo "A kritikus konfigurációk mostantól csak 'chattr -i' parancs után módosíthatók."
