# Debian Bootstrap Master Plan — 07_essential_packages.sh Inline Script

## 07: essential_packages.sh (inline változat a skeleton.sh-hoz)

```bash
# 07_essential_packages.sh inline

# Ellenőrzés: root
if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root!" >&2
  exit 1
fi

LOGFILE="/var/log/essential_packages.log"

# Lista: alapvető, minimal és biztonságos csomagok
ESSENTIAL_PACKAGES=(
  sudo
  vim
  curl
  wget
  git
  ca-certificates
  gnupg
  build-essential
  apt-transport-https
  lsb-release
  bash-completion
  net-tools
  iproute2
  iputils-ping
  rsyslog
  cron
)

# Telepítés minimálisan, no-recommends
for pkg in "${ESSENTIAL_PACKAGES[@]}"; do
  echo "Simulating install of $pkg..." | tee -a "$LOGFILE"
  apt-get -s install --no-install-recommends "$pkg" | tee -a "$LOGFILE"
  echo "Installing $pkg..." | tee -a "$LOGFILE"
  apt-get install -y --no-install-recommends "$pkg"
done

# Ellenőrzés, mi húzta fel a csomagokat
for pkg in "${ESSENTIAL_PACKAGES[@]}"; do
  echo "Dependencies for $pkg:" | tee -a "$LOGFILE"
  aptitude why "$pkg" | tee -a "$LOGFILE"
done

# Felesleges / orphan csomagok ellenőrzése
echo "Checking for orphan packages..." | tee -a "$LOGFILE"
apt autoremove -s | tee -a "$LOGFILE"
deborphan -a | tee -a "$LOGFILE"

# Befejezés
echo "07_essential_packages.sh completed. Logs in $LOGFILE"
```

### Megjegyzések / Direktívák

* Minden csomag minimálisan telepítve `--no-install-recommends`. Globális no-recommends szabály már érvényben.
* Minden telepítés előtt szimuláció (`-s`) fut, logban dokumentálva.
* `aptitude why` segít megérteni, mely csomag húzta fel a függőségeket.
* `apt autoremove` és `deborphan` szkript segítségével a felesleges csomagok ellenőrzése.
* Inline a skeleton.sh-ban, az orchestrator csak a fő scriptet hívja, nincs szükség külön fájlra.
* Log minden lépésről a `/var/log/essential_packages.log`-ba.
