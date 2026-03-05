### Cél:
A kernel modul alapú támadások, privilege escalation vektorok, rootkitek és firmware-exploitek elleni védelem.
Ez a szkript feketelistázza, eltávolítja és opcionálisan zárolja a kritikus, sebezhető vagy ritkán használt kernelmodulokat.

| Rész                                       | Funkció                                                 |
| ------------------------------------------ | ------------------------------------------------------- |
| `/etc/modprobe.d/hardening_blacklist.conf` | Tartalmazza a tiltott modulokat (Bea-lista).            |
| `/etc/hardening.conf`                      | Kapcsolófile, vezérli a végső kernelzárást.             |
| `/var/log/hardening_module_blacklist.log`  | Minden esemény naplózása.                               |
| `/var/backups/hardening/*.bak_*`           | Automatikus mentés a korábbi modprobe konfigurációkról. |

## Konfigurációs példa

/etc/hardening.conf
```bash
DISABLE_MODULE_LOADING_AFTER_BOOT=true
```
- true: a szkript a telepítés végén letiltja a modulbetöltést.
- false: csak a blacklist aktív marad, modulok továbbra is tölthetők.

# Folyamatleírás

- Mentés:
A rendszerben található összes /etc/modprobe.d/*.conf fájl mentésre kerül a /var/backups/hardening/ alá, időbélyeggel.

- Blacklist generálás:
A megadott veszélyes modulok listája bekerül a hardening_blacklist.conf-ba.
(Az .ko kiterjesztést a rendszer nem igényli, automatikusan felismeri a modulokat.)

- Runtime eltávolítás:
Az éppen betöltött tiltott modulokat modprobe -r próbálja eltávolítani.
Ha valamelyik használatban van, logolja a figyelmeztetést, de nem erőlteti a kilövést.

- Kernelzár ellenőrzés:

Ha nincs folyamatban apt vagy dpkg művelet,
és nem változott a kernel verzió az előző futáshoz képest,

akkor végrehajtja:
```bash
echo 1 > /proc/sys/kernel/modules_disabled
```

# Visszaállítás

Ha valamilyen okból (pl. új kernel driver telepítés) vissza kell engedni a modul loadingot:

- Reboot-old a rendszert – a kernel újra engedélyezi a modul betöltést.
- Szerkeszd a /etc/hardening.conf fájlt:
```bash
DISABLE_MODULE_LOADING_AFTER_BOOT=false
```
Futtasd újra a szkriptet:
```bash
sudo bash /path/to/17_module_blacklist.sh
```
Ez újraalkotja a blacklistet, de nem tiltja le a kernel modulkezelést.

# Pro Tipp

Ha image-t, ISO-t vagy dedikált szerver buildet csinálsz, célszerű az init után csak egyszer
futtatni ezt a szkriptet, majd:
```bash
systemctl mask systemd-modules-load.service  # ha systemd alatt fut
```
vagy SysV-n:
```bash
update-rc.d -f kmod remove
```

# Szerzői megjegyzés

Ez a modulvédelmi réteg nem „extra biztonság” — hanem kötelező hardening eleme minden olyan környezetben,
ahol firmware manipuláció, SMBus hozzáférés, hypervisor abuse vagy i2c-sinkhole támadás bármikor előfordulhat.
A lista egy valódi terepi tapasztalaton alapul, nem generikus CIS guideline – ezért van értéke.
Ez nem „tantermi biztonság”, hanem éles tűzvonalon tesztelt védelem.
