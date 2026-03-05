## Áttekintés

# A 00_install.sh egy hardcore, zárt bootstrap telepítő Debian-alapú rendszerekhez, amely:

- Memória-hardening: ASLR bekapcsolása, NX ellenőrzés

- C runtime védelem: beágyazott memguard LD_PRELOAD library a heap integritás ellenőrzésére

- Debootstrap integritás: minbase install ellenőrzése, libc/ld SHA256 és MD5 hash-ek

- Shared object védelem: libs hash-ek, aláírás, chmod + chattr +i próbálkozások

- LD loader védelem: ld.so.conf.d/skell.conf létrehozása, lockolása

- Ez a script idempotens, önálló, nem igényel külső orchestrator-t.

# Telepítés

 Rootként futtasd:
 ```bash
sudo bash 00_install.sh
```
# Logok:

- $LOGDIR/00_install_YYYYMMDD-HHMMSS.log

- $LOGDIR/00_integrity_YYYYMMDD-HHMMSS.log

- Memguard runtime aktiválása:

# Ellenőrzés

CANARY fájl:
```bash
cat /var/lib/skell/canary/system_memory_hardening.ok
# OK: system_memory_hardening active
```
ASLR és NX ellenőrzés:
```bash
cat /proc/sys/kernel/randomize_va_space
# 2 => OK

grep -qi nx /proc/cpuinfo && echo "NX supported"
```
Shared object integritás:
```bash
sha256sum -c /var/lib/skell/lib_integrity_YYYYMMDD-HHMMSS.txt
# (ellenőrizheted a fájlokat)
```

# Frissítés / visszaállítás

- Locked fájlok eltávolításához:
```bash
sudo chattr -i /etc/ld.so.conf.d/skell.conf
sudo chattr -i /usr/local/lib/memguard/*.so
```

- Script újrafuttatható frissítés előtt, majd újra lockolható:
```bash
sudo bash 00_install.sh
```

# Megjegyzések

- A script nem engedi, hogy a rendszer automatikus frissítései felülírják a hardeninget.

- A memguard csak userspace protection, kernel / BIOS hardver védelmeket nem helyettesít.

- A script idempotens és biztonságközpontú, így biztonságos VM-en vagy izolált környezetben tesztelni a legjobb.

  


Shell újraindítás után a /etc/profile.d/skell_memguard.sh biztosítja az automatikus LD_PRELOAD betöltést.

SUID/SGID binárisokra LD_PRELOAD nem hat.
