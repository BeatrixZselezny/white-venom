# fájl létrehozása

``bash

sudo tee /etc/apt/apt.conf.d/99no-recommends <<'EOF'
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF

``

# Magyarázat:

- Install-Recommends "0" — a Recommends soha nem települ automatikusan.

- stall-Suggests "0" — a Suggests sem (ez amúgy alapértelmezésben nem automata, de így biztosítod).

# Alternatív (per‑install) megoldás:

`` bash
sudo apt install --no-install-recommends <csomag>
``
Használd ezt alapértelmezett viselkedésként: globálisan tiltsd, és ha valami tényleg kell, telepítsd kézzel.

## Mindig szimulálj telepítést — nézd meg, mit húz fel

Mielőtt bármit telepítesz, lásd, mi kerül fel:

`` bash
apt-get -s install <csomag>        # -s = simulate / show what would happen
apt install --no-install-recommends -s <csomag>
``
Ez megmutatja a függőségi fa‑t és a csomagok listáját (így nem lep meg a „kiszórás”).

# Minimal root / bootstrap: debootstrap --variant=minbase
Ha új rendszert készítesz, debootstrap‑szal kihozhatsz nagyon minimális telepítést:

`` bash
debootstrap --variant=minbase bookworm /mnt/debian http://deb.debian.org/debian
``
minbase nem húzza fel a recommended csomagokat és jóval tisztább kezdőállapotot ad.

# Ellenőrzés: mely csomagok „automatikusan telepítettek” és feleslegesek?
Hasznos eszközök:

``bash
aptitude search '~i !~M'    # telepített, de manuálisan jelölt (nem auto)
aptitude search '~M'       # auto‑installed packages (amiket eltávolíthatsz, ha nincsenek függők)
apt autoremove --simulate
deborphan                  # roncs libs keresésére
``
apt autoremove és deborphan segít a felesleges csomagok tisztításában.

# Ha egy meta‑csomag tömör felfújást hoz — kerüld a meta csomagokat
Meta‑csomagok (pl. task-gnome-desktop, kde-standard, ubuntu-desktop, vagy egyes „lamp” pakkok) gyakran húznak fel rengeteg dolgot. Általában jobb a komponenseket külön telepíteni.

Példa: ha csak sshd kell, ne telepítsd a openssh-server‑t egy „task” csomaggal, telepítsd rendesen apt install --no-install-recommends openssh-server.

# Dummy / shim csomagok: equivs — ha muszáj „satisfy” csomagfüggőséget
Néha egy csomag azt mondja „függök X-től”, de az X egy nagy, számodra felesleges csomag. equivs-szel létrehozhatsz egy kisméretű „dummy” csomagot, ami azt a nevet adja (nem tartalmazza a nagy cuccot).

Telepítés:
``bash
sudo apt install equivs
mkdir ~/equivs && cd ~/equivs
equivs-control myshim
# szerkeszd a myshim fájlt: Package: lib-heavyshim, Version: 1.0, Provides: lib-heavy, Description: shim
equivs-build myshim
sudo dpkg -i lib-heavyshim_1.0_all.deb
``
FIGYELMEZTETÉS: ez power‑tool — csak ha pontosan tudod, hogy miért csinálod. Ha rosszul használod, törékeny függőségi állapotot hozhatsz létre.

# Célzott policy: apt preferences és pinning
Ha nem akarod bizonyos forrásokból automatikusan felhúzni csomagokat, vagy szeretnéd erősen preferálni a biztonsági csomagokat, használj pin‑t:

/etc/apt/preferences.d/security példa:

Package: *
Pin: release a=security
Pin-Priority: 1001

Ez nem közvetlenül a „felesleges csomagok” ellen van, de kontroll alatt tartja a forrásokat.

# Automatizált szabályrendszer telepítés előtt — script checklist

Készíts magadnak egy telepítés előtti ellenőrző scriptet, amit mindig futtatsz:

``bash
#!/bin/bash
# preinstall-check.sh
if apt-get -s install "$1" | grep -q "The following NEW packages will be installed:"; then
  apt-get -s install "$1"
else
  echo "Nincs telepítéshez szükséges változás."
fi
``
Jobb, ha per‑install kézzel ellenőrzöd a listát és csak azután nyomsz apt install --no-install-recommends.

# Konkrét gyakorlatias workflow (ajánlott)

- Globálisan tiltsd a recommends‑et (/etc/apt/apt.conf.d/99no-recommends).

- Mindig apt-get -s install <csomag> futtasd — nézd meg a listát.

- telepíts apt install --no-install-recommends <csomag>.

- Ha egy újonnan telepített csomag oldalági függőségeit vizsgálod, aptitude why <csomag> segít megérteni, mi húzta fel.

- Rendszeresen futtasd apt autoremove és deborphan.

- Ha meta‑csomag húz fel sok mindent, boncold le és telepítsd kézzel a tényleges szükséges komponenseket.

- Ha nulláról építesz, használd debootstrap --variant=minbase.

# Példák — tipikus parancsok (összefoglaló)

``bash
# globális letiltás
sudo tee /etc/apt/apt.conf.d/99no-recommends <<'EOF'
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF

# szimuláció
apt-get -s install openssh-server

# telepítés minimálisan
sudo apt install --no-install-recommends openssh-server

# ellenőrzés, ki húzott fel mit
aptitude why <felesleges-csomag-neve>

# törlés javaslat
sudo apt autoremove

# deborphan alapú orphan hunt
sudo apt install deborphan
deborphan

# minimal base telepítés
sudo debootstrap --variant=minbase bookworm /mnt/debian http://deb.debian.org/debian
``

# Végső gondolatok / kockázatok
Ha mindig --no-install-recommends-sel dolgozol, előfordulhat, hogy egy funkció hiányzik, mert azt a Recommends biztosította. Ezért mindig ellenőrizd a telepített csomagok működését — néha kézzel kell telepíteni egy‑két „ajánlott” csomagot.

equivs erős eszköz: használata szakértői döntés kell legyen.

A legbiztosabb: build minimal rendszert (debootstrap) és csak a szükséges csomagokat add hozzá kontrolláltan.



