# 09_ipv6_only_kernel.sh inline


# Ellenőrzés: root
if [ "$(id -u)" -ne 0 ]; then
echo "Run as root!" >&2
exit 1
fi


LOGFILE="/var/log/ipv6_only_kernel.log"


# 1. IPv6 engedélyezés / IPv4 tiltás a kernel szinten
SYSCTL_FILE="/etc/sysctl.d/99-ipv6-only.conf"
cat > "$SYSCTL_FILE" <<'EOF'
# IPv6 only configuration
net.ipv4.conf.all.disable_ipv4 = 1
net.ipv4.conf.default.disable_ipv4 = 1
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
EOF


# 2. sysctl élesítése
sysctl --system | tee -a "$LOGFILE"


# 3. Ellenőrzés
IPV4_ENABLED=$(sysctl net.ipv4.conf.all.disable_ipv4 | awk '{print $3}')
IPV6_ENABLED=$(sysctl net.ipv6.conf.all.disable_ipv6 | awk '{print $3}')


if [ "$IPV4_ENABLED" -eq 1 ] && [ "$IPV6_ENABLED" -eq 0 ]; then
echo "IPv6-only kernel configuration active" | tee -a "$LOGFILE"
else
echo "IPv6-only configuration failed!" | tee -a "$LOGFILE"
fi


# 4. Log és befejezés
echo "09_ipv6_only_kernel.sh completed. Logs in $LOGFILE"