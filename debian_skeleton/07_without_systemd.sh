# 06_without_systemd.sh inline


# Ellenőrzés: root
if [ "$(id -u)" -ne 0 ]; then
echo "Run as root!" >&2
exit 1
fi


LOGFILE="/var/log/no_systemd.log"


# BLACKLIST: systemd telepítésének megakadályozása
BLACKLIST=(systemd systemd-sysv libsystemd0 libsystemd-journal0)


# Telepítés előtti filter
apt_prevent_systemd() {
for pkg in "${BLACKLIST[@]}"; do
if dpkg -l | grep -q "$pkg"; then
echo "$pkg is installed — removing..." | tee -a "$LOGFILE"
apt-get purge -y "$pkg"
fi
done
}


export -f apt_prevent_systemd


# APT telepítéskor tiltsuk a BLACKLIST csomagokat (DPkg::Pre-Install-Pkgs)
APT_CONF_DIR="/etc/apt/apt.conf.d"
mkdir -p "$APT_CONF_DIR"
cat > "$APT_CONF_DIR/99-prevent-systemd" <<'EOF'
DPkg::Pre-Install-Pkgs {
"/bin/bash -c 'apt_prevent_systemd'";
};
EOF


# Init.d telepítés és alapértelmezett runlevel
apt-get install -y sysv-rc
for svc in ssh networking cron rsyslog; do
update-rc.d $svc defaults
invoke-rc.d $svc start
done


# Ellenőrzés: nincs futó systemd process
if pgrep systemd >/dev/null; then
echo "systemd processes running!" | tee -a "$LOGFILE"
exit 1
else
echo "No systemd detected, init.d active." | tee -a "$LOGFILE"
fi


echo "06_without_systemd completed. Logs in $LOGFILE"