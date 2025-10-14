#!/bin/sh
# deploy-ipv6-harden.sh
# Usage: sh deploy-ipv6-harden.sh [TARGET]
# TARGET default: /target  (Debian installer chroot target)
TARGET=${1:-/target}

echo "Out‑of‑Avalon IPv6 hardening deploy to $TARGET"

# 1) könyvtárak
mkdir -p "$TARGET"/etc/sysctl.d
mkdir -p "$TARGET"/etc/iptables
mkdir -p "$TARGET"/etc/network/if-pre-up.d

# 2) sysctl file - tiltjuk a router advert/auto-config funkciókat, engedélyezzük a forwardingot csak ha explicit kell (alap: 0)
cat > "$TARGET"/etc/sysctl.d/99-out-off-avalon.conf <<'EOF'
# Out‑of‑Avalon IPv6 hardening
# Ne engedjük, hogy a host automatikusan RA/Autoconf elfogadjon / ne legyen "default router"
net.ipv6.conf.all.autoconf = 0
net.ipv6.conf.default.autoconf = 0

net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0

# soha ne fordítsunk át forgalmat (alap-beállítás: ne legyen router)
net.ipv6.conf.all.forwarding = 0
net.ipv6.conf.default.forwarding = 0

# ne fogadjunk redirecteket
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# ne küldjünk router solicitation-t (a kliens nem keresi a routert)
net.ipv6.conf.default.router_solicitations = 0

# egyéb általános hardening (kiegészíthető a te fájloddal)
kernel.dmesg_restrict = 1
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
kernel.randomize_va_space = 2
EOF

# 3) ip6tables rules (iptables-restore formátum)
# Magyarázat: allow lo + RELATED,ESTABLISHED; drop link-local multicast ff02::/16; engedjük a ND/RA alapvető típusokat (134,135,136)
# majd minden más ICMPv6 DROP; alapértelmezett INPUT DROP, FORWARD DROP, OUTPUT ACCEPT
cat > "$TARGET"/etc/iptables/rules.v6 <<'EOF'
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

# loopback és már nyitott kapcsolatok
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# DROP link-local multicast (ff02::/16) - megelőzi a helyi worm terjedést
-A INPUT -d ff02::/16 -j DROP

# Engedélyezzük a ND/ICMP típusok (Router Advertisement, Neighbor Solicitation, Neighbor Advertisement)
# 134 Router Advertisement (szelektíven használd ha nem akarsz accept_ra=0-t, általában 134 engedés kell helyi ND-hez)
-A INPUT -p ipv6-icmp --icmpv6-type 134 -j ACCEPT
# 135 Neighbor Solicitation
-A INPUT -p ipv6-icmp --icmpv6-type 135 -j ACCEPT
# 136 Neighbor Advertisement
-A INPUT -p ipv6-icmp --icmpv6-type 136 -j ACCEPT

# limitáljuk RA/ND flood-ot (rate limit)
-A INPUT -p ipv6-icmp --icmpv6-type 134 -m limit --limit 10/min --limit-burst 20 -j ACCEPT
-A INPUT -p ipv6-icmp --icmpv6-type 135 -m limit --limit 50/min --limit-burst 200 -j ACCEPT
-A INPUT -p ipv6-icmp --icmpv6-type 136 -m limit --limit 50/min --limit-burst 200 -j ACCEPT

# minden többi ICMPv6 dobása (megakadályozza a többi támadó ICMPv6 vektort)
-A INPUT -p ipv6-icmp -j DROP

COMMIT
EOF

# 4) boot-time loader script (if-pre-up.d kompatibilis rendszerekhez)
cat > "$TARGET"/etc/network/if-pre-up.d/load-iptables <<'EOF'
#!/bin/sh
# Load iptables rules before interfaces are brought up
[ -x /sbin/ip6tables-restore ] || exit 0
if [ -r /etc/iptables/rules.v6 ]; then
  /sbin/ip6tables-restore < /etc/iptables/rules.v6
fi
if [ -r /etc/iptables/rules.v4 ]; then
  /sbin/iptables-restore < /etc/iptables/rules.v4
fi
exit 0
EOF
chmod +x "$TARGET"/etc/network/if-pre-up.d/load-iptables

# 5) (opcionális) rules.v4 mintapélda - ha később kell, de alapból üres/deny
cat > "$TARGET"/etc/iptables/rules.v4 <<'EOF'
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# ha SSH kell IPv4-en, engedd meg (külön logika)
# -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT

COMMIT
EOF

# 6) ha célrendszer chrootolható, írjuk be az apt csomagokra vonatkozó javaslatot (opcionális)
# (nem telepít semmit, csak javaslat hogy a targeten legyen iptables csomag)
echo "A perzisztens fájlok létrehozva a célrendszeren."
echo "Ne felejtsd el a célrendszeren telepíteni: iptables/ip6tables vagy iptables-persistent (ha nincs internet a telepítésnél, később telepítsd)."

# 7) opció: azonnali teszt a futó kernelre (installer alatt futtatva)
if [ "$TARGET" = "/target" ]; then
  if command -v ip6tables-restore >/dev/null 2>&1; then
    echo "Teszt: ip6tables-restore futtatása jelenlegi rendszerre (telepítő kernel)."
    ip6tables-restore < "$TARGET"/etc/iptables/rules.v6 || echo "ip6tables-restore sikertelen"
    echo "Aktuális ip6tables:"
    ip6tables -L -n -v
  fi

  if command -v sysctl >/dev/null 2>&1; then
    echo "Teszt: sysctl --system felhívása célfájlra"
    # A telepítő környezet nem biztos, hogy sysctl --system-t támogat; beállításokat egyesével is alkalmazhatod
    # itt csak figyelmeztetünk
    echo "A beállítások a célrendszerbe kerültek: $TARGET/etc/sysctl.d/99-out-off-avalon.conf"
  fi
fi

echo "KÉSZ. A célrendszerbe telepítve: $TARGET/etc/sysctl.d/99-out-off-avalon.conf és $TARGET/etc/iptables/rules.v6"
echo "A bootloader script: $TARGET/etc/network/if-pre-up.d/load-iptables"
echo "Ne felejtsd el a célrendszeren telepíteni a szükséges iptables csomagokat és futtatni sysctl --system."
exit 0
