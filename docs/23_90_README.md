### Kritikus Útvonalak Logikai Védelme (chattr +i)

# Cél:

Ez a dokumentáció a rendszerkritikus konfigurációs fájlok védelmét szolgáló mechanizmust írja le. A védelem a Linux fájlrendszer-attribútumok
(Extended Attributes) használatával történik, a chattr +i (immutable) flag beállításával, ami megakadályozza a root általi véletlen
vagy rosszindulatú módosítást.

A mechanizmus két külön szkriptből áll, amelyek a biztonság és a rendszerfrissítések egyensúlyát biztosítják.

## I. A Lezáró Szkript: 23_immutable_critical_paths.sh

# Célja:

A hardening folyamat lezárása. A legfontosabb konfigurációs fájlok (amelyeket a hardening során módosítottunk)
lezárása a chattr +i attribútummal.

# Hatása

A lezárt fájlok nem módosíthatók, törölhetők, vagy nevezhetők át még a root felhasználó által sem. Ez egy erős védelmi vonal
a jogosultság-emelést követő támadások ellen.

# Használat

Ezt a szkriptet minden nagyobb rendszerfrissítés után vagy a teljes hardening folyamat végén kell futtatni.
```bash
sudo ./23_immutable_critical_paths.sh
```

# Főbb Védett Fájlok

- Rendszerboot és kernel: /etc/default/grub, /etc/modprobe.d/blacklist.conf
- Jogosultságok: /etc/passwd, /etc/shadow, /etc/sudoers
- Fájlrendszer és Linker: /etc/fstab, /etc/ld.so.preload
- Sysctl hardening: /etc/sysctl.d/*

## II. A Feloldó Szkript: 90_release_locks.sh

# Célja

A lezárás ideiglenes feloldása karbantartás céljából. Ez a szkript elvégzi a chattr -i parancsot
a kritikus fájlokon.

# Hatása

A fájlok védelme ideiglenesen megszűnik, így a csomagkezelő (pl. apt) futtathat frissítéseket
és a rendszeradminisztrátor is végezhet manuális módosításokat.

## KRITIKUS HASZNÁLAT

Ezt a szkriptet minden frissítés (pl. apt upgrade) előtt futtatni kell! Enélkül
a frissítés hibába ütközik és megszakad.
```bash
sudo ./90_release_locks.sh
```

# Karbantartási Protokoll (Zero-Trust Ciklus)

Az immutable védelem használata megköveteli a szigorú karbantartási protokollt:

Lépés,Parancs,Cél
1. FELOLDÁS,sudo ./90_release_locks.sh,Lezárások feloldása a frissítés előtt.
2. FRISSÍTÉS,sudo apt update && sudo apt upgrade,A rendes rendszerfrissítés elvégzése.
3. VISSZAZÁRÁS,sudo ./23_immutable_critical_paths.sh,Azonnali visszazárás a frissítés után.
4. AUDIT,lsattr /etc/fstab /etc/shadow,"Ellenőrzés, hogy a védelmi attribútumok érvényben vannak-e (i betű)."

# figyelmeztetés:
Soha ne hagyja a rendszert a 3. lépés utáni lezárás nélkül. A lezárás nélküli állapot a legsebezhetőbb.

