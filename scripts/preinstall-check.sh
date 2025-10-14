#!/usr/bin/env bash
# preinstall-check.sh
# Egyszerű segédszkript: szimulálja a telepítést és kiemeli,
# milyen csomagok kerülnének fel (új/ajánlott/suggested),
# ráadásul figyelmeztet, ha "tiltott" csomag(ok) (pl. systemd*) felkerülnének.
#
# Használat: ./preinstall-check.sh csomag1 csomag2 ...
# Példa:    ./preinstall-check.sh openssh-server wireguard

set -eu

if ! command -v apt-get >/dev/null 2>&1; then
  echo "Ez a script Debian/Ubuntu apt alapú rendszerre készült. apt-get nincs telepítve." >&2
  exit 2
fi

if [ $# -lt 1 ]; then
  echo "Használat: $0 csomag1 [csomag2 ...]" >&2
  exit 1
fi

# Konfigurálható tiltott minták (glob)
# Ha bármelyik jön fel a telepítéssel, figyelmeztetünk.
FORBIDDEN_PATTERNS=("systemd*" "gnome*" "kde*" "udisks2" "gvfs*" "gdm3" "pulseaudio*")

# Per‑install sim (apt-get -s)
echo "=== SIMULÁCIÓ: apt-get -s install $* ==="
SIM_OUT=$(apt-get -s install --no-install-recommends "$@" 2>&1) || SIM_OUT="$SIM_OUT"

# Kiemelt rész: "The following NEW packages will be installed:"
NEW_PKGS=$(echo "$SIM_OUT" | awk '/The following NEW packages will be installed:/{flag=1; next} /^$/{flag=0} flag{print}' | tr -d ',' | tr '\n' ' ')

# Kiemelt rész: Recommends (ha nincs --no-install-recommends használva)
RECOMMENDS=$(echo "$SIM_OUT" | awk '/The following packages will be upgraded:|The following packages will be installed:|The following additional packages will be installed:/{flag=1; next} /^$/{flag=0} flag{print}' | sed -n '1,3p' | tr '\n' ' ')

echo
if [ -z "$NEW_PKGS" ]; then
  echo ">> Nincsenek új, telepítendő csomagok a szimuláció szerint (vagy csak recommends/suggests jelent meg)."
else
  echo "Új csomagok, amik települnének: "
  echo "$NEW_PKGS" | sed 's/  */ /g'
fi

echo
echo "=== Részletes apt-get output (részlet) ==="
echo "$SIM_OUT" | sed -n '1,200p'
echo "=== vége ==="
echo

# Ellenőrizzük a tiltott mintákat
echo "Ellenőrzés tiltott mintákra..."
IFS=' ' read -r -a NEWARR <<< "$NEW_PKGS"
for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
  for pkg in "${NEWARR[@]}"; do
    case "$pkg" in
      $pattern)
        echo "!!! FIGYELMEZTETÉS: a telepítés során felkerülő tiltott csomag: $pkg (pattern: $pattern)" >&2
        ;;
    esac
  done
done

# Ajánlat: mutassuk meg, ha a recommends telepítene plusz csomagokat
echo
echo "Megjegyzés: a script --no-install-recommends paraméterrel szimulál. Ha nem használod a --no-install-recommendset, további 'Recommends' csomagok jöhetnek fel."
echo "Ha biztos akarsz lenni, futtasd: apt-get -s install --no-install-recommends <csomag> és nézd át a listát."
echo
echo "Kiegészítés: ha el akarod kerülni, hogy az apt ajánlott csomagokat telepítse, tedd be:"
echo "sudo tee /etc/apt/apt.conf.d/99no-recommends <<'EOF'"
echo 'APT::Install-Recommends "0";'
echo 'APT::Install-Suggests "0";'
echo 'EOF'
echo

exit 0

