#!/bin/bash
# 90_release_locks.sh - Ideiglenesen feloldja a kritikus fájlok védelmét a frissítésekhez (chattr -i)

echo "--- 90_release_locks: Kritikus fájlok feloldása karbantartáshoz ---"

# 1. Kritikus fájlok listája (ugyanaz, mint a 23-ban)
CRITICAL_FILES=(
    "/etc/default/grub"
    "/etc/modprobe.d/blacklist.conf"
    "/etc/sysctl.d/70-ptrace-lockdown.conf"
    "/etc/sysctl.d/90-hardening.conf"
    "/etc/ld.so.preload"
    "/etc/ld.so.conf"
    "/etc/ld.so.conf.d"
    "/etc/fstab"
    "/etc/passwd"
    "/etc/shadow"
    "/etc/group"
    "/etc/sudoers"
    "/etc/network/interfaces"
    "/etc/resolv.conf"
    "/etc/hosts"
)

# 2. Chattr -i attribútum eltávolítása (Feloldás)
echo "2. Chattr -i attribútum eltávolítása a karbantartáshoz..."
for FILE in "${CRITICAL_FILES[@]}"; do
    if [ -e "$FILE" ]; then
        # -V: verbose, -i: feloldás
        chattr -i "$FILE" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "   -> FELOLDVA: $FILE (chattr -i)"
        fi
    fi
done

echo "--- 90_release_locks Befejezve ---"
echo "FIGYELEM: A frissítések után ne feledje futtatni a 23_immutable_critical_paths.sh szkriptet a lezáráshoz!"
