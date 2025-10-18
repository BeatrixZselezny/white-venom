# Ellenőrzés: root user
if [ "$(id -u)" -ne 0 ]; then
echo "Run as root!" >&2
exit 1
fi


LOGFILE="/var/log/apt-preinstall.log"
BLACKLIST=(systemd systemd-sysv libsystemd0 libsystemd-journal0)
DRY_RUN=0 # 1 = csak naplóz, nem blokkol


# Globális no-recommends és no-suggests policy
sudo tee /etc/apt/apt.conf.d/99no-recommends <<'EOF'
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF


# Wrapper function for DPkg::Pre-Install-Pkgs
apt_preinstall_filter() {
while read -r pkg; do
for b in "${BLACKLIST[@]}"; do
if [[ "$pkg" == *$b* ]]; then
echo "Blocked pre-install of $pkg" | tee -a "$LOGFILE"
if [ "$DRY_RUN" -eq 0 ]; then
exit 1
fi
fi
done
done
}


export -f apt_preinstall_filter


# Apt configuration snippet
APT_CONF_DIR="/etc/apt/apt.conf.d"
mkdir -p "$APT_CONF_DIR"
cat > "$APT_CONF_DIR/99-preinstall-filter" <<'EOF'
DPkg::Pre-Install-Pkgs {
"/bin/bash -c 'apt_preinstall_filter'";
};
EOF


# Preferences minták (pinning)
PREF_DIR="/etc/apt/preferences.d"
mkdir -p "$PREF_DIR"
cat > "$PREF_DIR/99-stable-pin" <<'EOF'
Package: dpkg libc6 openssl
Pin: release a=stable
Pin-Priority: 1001
EOF


# Unattended-upgrades sablon
cat > "$APT_CONF_DIR/50unattended-upgrades" <<'EOF'
Unattended-Upgrade::Allowed-Origins {
"Debian stable-security";
};
Unattended-Upgrade::Automatic-Reboot "false";
EOF


# Mentés rollbackhez
BACKUP_DIR="~/apt_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r "$APT_CONF_DIR" "$BACKUP_DIR"
cp -r "$PREF_DIR" "$BACKUP_DIR"


# Teszt (simulált telepítés)
echo "Test install of safe-package" | apt_preinstall_filter


echo "05_dpkg_apt_hardening completed. Logs in $LOGFILE"
# 8. Equivs: csak szakértői használat!