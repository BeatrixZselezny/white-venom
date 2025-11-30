# APT policy és telepítési irányelvek (Out‑of‑Avalon)

Ez a dokumentum a személyes, minimalista Debian rendszereken alkalmazott APT-policy-t és
gyakorlati szabályokat tartalmazza — cél: **minimális függőségi felfújás**, **systemd elkerülése**
és biztonságos telepítés.

## Alapelvek
- **Globálisan tiltsd a Recommends/Suggests automatikus telepítését.**
- Minden telepítés előtt futtass szimulációt (`apt-get -s install`) — nézd meg, mit húz fel.
- Ha egy csomag nagy meta‑csomagot vagy kurrens desktop stacket akarna felhúzni, inkább
  kézzel telepítsd a szükséges komponenseket.
- Ha egy csomag erősen függ egy nem kívánt pakkól (pl. `systemd`), használd a PIN mechanizmust
  (APT pinning) vagy `equivs`‑et csak tudatosan.

---

## Gyors beállítások (konkrét parancsok)

### 1) Recommends automatikus telepítésének letiltása
``bash
sudo tee /etc/apt/apt.conf.d/99no-recommends <<'EOF'
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF
``

Ez globális és megakadályozza, hogy az `apt install` ajánlott csomagokat húzzon fel.

 Alternatíva per‑install: `apt install --no-install-recommends <csomag>`

### 2) Rendszeres szkennelés telepítés ELŐTT
Mindig futtasd:
``bash
apt-get -s install <csomag>
``

Ellenőrizd a kimenetet: milyen *új* csomagok, milyen *additional* csomagok jönnek fel.

### 3) PIN (APT preferences) a systemd vagy bármely más csomag blokk
Példa: **tiltsuk le bármilyen `systemd*` csomag telepítését**:

``bash
sudo tee /etc/apt/preferences.d/no-systemd.pref <<'EOF'
Package: systemd*
Pin: release *
Pin-Priority: -1
EOF
``


Ez a beállítás megakadályozza, hogy az APT bármilyen `systemd*` nevű csomagot telepítsen vagy frissítsen.
**Figyelem**: pin‑elésnél mindig tesztelj chrootban vagy virtuális gépen, nehogy váratlan függőségi törést okozzon.

 Ezen felül használhatsz `apt-mark hold <csomag>`-ot is, hogy meglévő telepített csomagokat befagyass.

### 4) Dummy csomagok — equivs
Ha egy csomag neve miatt próbálnak felhúzni egy nagy meta‑csomagot, amit nem akarsz,
`equivs`‑szel létrehozhatsz egyszerű "shim" csomagot.

Telepítés és egyszerű példa:
``bash
sudo apt install equivs
equivs-control myshim
``
### szerkeszd myshim fájlt: Package: lib-heavyshim, Version: 1.0, Provides: lib-heavy
``bash
equivs-build myshim
sudo dpkg -i lib-heavyshim_1.0_all.deb
``

**Figyelem**: csak haladó használat — rossz shim törékeny függőségi állapotot okozhat.

### 5) MinBase install új rendszernél (debootstrap)
Ha nulláról építesz rendszert, használd:

``bash
debootstrap --variant=minbase bookworm /mnt/debian http://deb.debian.org/debian
``

`minbase` a legkevesebb csomagot telepíti — később szelektíven adod hozzá a szükségeseket.

### 6) Automatikus tisztítás
Rendszeresen használd:

``bash
sudo apt autoremove
sudo apt install deborphan
deborphan
``

### 7) Vizsgálat: "Mi húzta fel?"
Segít megérteni, hogy mely csomag vagy meta‑csomag idézte elő.

## Tippek és óvintézkedések
- PIN‑elés és equivs használata erős, de veszélyes: mindig legyen recovery opciód (konzol, rescue ISO).
- Ha tizenkét connecté vagy remote gépen dolgozol: soha ne teszteld először ssh‑n keresztül a tűzfalszabályokat, mert könnyen kiszakadhatsz.
- Privát kulcsokat vagy érzékeny adatokat **soha** ne pusholj a GitHubra — még privát repo esetén sem javasolt.
- Tesztelj minden policy‑t egy VM‑ben vagy chroot‑ban a gyártás előtt.

---

## Ajánlott workflow
1. Telepítési terv, lista: mit akarsz telepíteni.
2. `preinstall-check.sh` futtatása.
3. `apt-get -s install --no-install-recommends ...` ellenőrzés.
4. Telepítés `--no-install-recommends` opcióval, majd manuális hiányzó komponensek telepítése.
5. `apt autoremove` és `deborphan` ellenőrzés.


---

# 3) APT pin minták — systemd tiltása (gyakorlati)
Mentésre: `etc-samples/no-systemd.pref` (vagy azt vedd át `/etc/apt/preferences.d/no-systemd.pref`‑ként)

```text
Package: systemd*
Pin: release *
Pin-Priority: -1

Ez megakadályozza, hogy az APT bármilyen systemd* csomagot telepítsen. Ha már telepítve van, megfontolandó az apt-mark hold:

sudo apt-mark hold systemd systemd-sysv libsystemd0

Fontos: ha eltávolítod a systemd‑t helyből, gondoskodj arról, hogy van működő init rendszer (sysvinit-core / runit), különben boot‑problémák lehetnek. Teszteld VM‑ben előbb.
4) debootstrap --variant=minbase lépésről lépésre (systemd‑mentes kiinduló rendszer)

Ez a rész úgy van megírva, hogy gyorsan le tudd hozni egy minimális Debian rendszert (minbase), amit aztán tetszés szerint bővítesz – és előre megmutatja, hogyan kerüld el, hogy a telepítés felhúzza a felesleges csomagokat.

    Feltételezések: van egy live Linux környezeted vagy rescue USB, root hozzáférésed a gépen, a lemezt/partíciókat létrehoztad.

Particionálás (például /dev/sda1 = root, /dev/sda2 = swap)

/sda partícionálás nem részletes itt — használd cfdisk/parted‑et. Példa:

mkfs.ext4 /dev/sda1
mkswap /dev/sda2
mount /dev/sda1 /mnt
swapon /dev/sda2

debootstrap

    Telepítsd a szükséges eszközöket a live rendszeren:

sudo apt update
sudo apt install debootstrap

    futtasd debootstrap‑t:

sudo debootstrap --variant=minbase bookworm /mnt http://deb.debian.org/debian

(bookworm helyett trixie vagy a kívánt kiadás)

    Chroot be:

for d in /dev /dev/pts /proc /sys /run; do sudo mount --bind $d /mnt$d; done
sudo chroot /mnt /bin/bash

    Alap beállítás chrootban:

export DEBIAN_FRONTEND=noninteractive
apt update

# alap policy: ne telepítsen recommends-t
mkdir -p /etc/apt/apt.conf.d
cat > /etc/apt/apt.conf.d/99no-recommends <<'EOF'
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF

# PIN systemd (ha akarod azonnal)
cat > /etc/apt/preferences.d/no-systemd.pref <<'EOF'
Package: systemd*
Pin: release *
Pin-Priority: -1
EOF

# telepítsük a minimális csomagokat: kernel, ssh, nano, grub, init (sysvinit-core)
apt update
apt install --no-install-recommends linux-image-amd64 grub-pc openssh-server nano sysvinit-core net-tools iproute2 iputils-ping --yes

# beállítások: hostname, fstab, locale, passwd
echo "myhost" > /etc/hostname
echo "127.0.0.1 localhost" > /etc/hosts
# passwd root
passwd root

# fstab példa
cat > /etc/fstab <<'EOF'
/dev/sda1  /     ext4  defaults  0 1
/dev/sda2  none  swap  sw        0 0
EOF

# localtime, locale (opcionális)
ln -fs /usr/share/zoneinfo/Europe/Budapest /etc/localtime
dpkg-reconfigure -f noninteractive locales || true

# grub telepítése (ha chrootban van a lemez)
grub-install /dev/sda
update-grub

# alap services: sshd legyen engedélyezve init.d-ben (sysv init)
# kilépés chrootból után unmount

    Kilépés és unmount:

exit
for d in /run /sys /proc /dev/pts /dev; do sudo umount /mnt$d || true; done
sudo umount /mnt
swapoff /dev/sda2

    Reboot — a gép most egy nagyon minimális, sysvinit alapú Debian rendszerrel fog elindulni. Innen kézzel telepítsd a szükséges csomagokat --no-install-recommends opcióval, és használd a preinstall-check.sh‑t minden új telepítés előtt.

Záró megjegyzések, biztonság és tesztelés

    Minden PIN‑ és equivs‑műveletet először VM‑ben tesztelj.

    Ha bármikor azt látod, hogy az apt valami kritikus csomagot akar felhúzni (systemd, gdm, pulse, stb.), állítsd le a telepítést és vizsgáld meg a függőségeket (apt-cache rdepends / aptitude why).

    Ne tárold a privát kulcsokat a publikus repo‑ban; a configokat pushold, de a kulcsokat tartsd offline/secret helyen.
```

