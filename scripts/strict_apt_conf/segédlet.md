#strict_apt_conf/ könyvtár tartalma (Trixie-hez)

Ezt majd csak bemásolod a friss rendszeredre:
/etc/apt/apt.conf.d/ alá, minden fájl neve maradhat az itt látott.

# 00aptitude-clean.conf

Csak azt telepíti, amit te mondasz, semmi mellékíz, semmi “ajánlott csomag”.

# 01strict-verification.conf

Minden csomag aláírást és érvényes tanúsítványt igényel.
Ez leállítja a telepítést, ha valami gyanús.

# 02no-systemd.conf

Ezzel a kis trükkel minden telepítés előtt kiszűröd a systemd-csomagokat.
(A log a /tmp/apt-filter.log-ba kerül, hogy tudd, mit dobott ki.)


# 03safe-upgrade.conf

A apt upgrade nem fog új csomagot behozni, csak frissít, amit már engedélyeztél


# 04pinning-strict.pref

Ez lefagyasztja a rendszert Trixie ágon —
semmi “unstable” vagy random backport nem mászik be.

# 05log-policy.conf

Ez elment minden tranzakciót a terminálra, és megőrzi a régi konfigokat upgrade-nél.


## Használat röviden

# A telepítés után (még chrootban, vagy az első boot után):

``bash
mkdir -p /etc/apt/apt.conf.d/
cp -a ~/strict_apt_conf/* /etc/apt/apt.conf.d/
cp -a ~/strict_apt_conf/04pinning-strict.pref /etc/apt/preferences.d/
``

# Ellenőrzés:

``bash
apt-cache policy
cat /etc/apt/apt.conf.d/02no-systemd.conf
``

# Majd futtass egy próba update-et:

apt-get update
apt-get upgrade --dry-run

# Ha minden tisztán lefut, és a apt-get upgrade nem próbál systemd-t betolni, akkor kész a tiszta Trixie-ed.


# verify_apt_integrity.sh

Helyezd pl. ide:
/usr/local/sbin/verify_apt_integrity.sh

