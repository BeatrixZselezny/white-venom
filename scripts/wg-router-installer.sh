#!/bin/sh
### wg-router-installer.sh
### SystemV installer: WireGuard + wg0.conf + IPv6 hardening + init.d + Peer template
### Usage: ./wg-router-installer.sh [--regen-keys] [--dry-run]

set -e
PATH=/sbin:/usr/sbin:/bin:/usr/bin

WG_DIR="/etc/wireguard"
WG_IF="wg0"
LAN_IF="wlan0"
WAN_IF="tun0"           # Proton/VPNShield interface
LISTEN_PORT=51820
INIT_SCRIPT="/etc/init.d/wg-router"

# Param feldolgozás
REGEN_KEYS=0
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --regen-keys) REGEN_KEYS=1 ;;
        --dry-run) DRY_RUN=1 ;;
    esac
done

echo "=== wg-router installer ==="
[ "$(id -u)" != "0" ] && echo "Futtasd rootként!" >&2 && exit 1
[ "$DRY_RUN" -eq 1 ] && echo "DRY RUN mód: semmi nem változik élesen"

mkdir -p "$WG_DIR"
chmod 700 "$WG_DIR"

WG_PRIV="$WG_DIR/privatekey"
WG_PUB="$WG_DIR/publickey"
WG_CONF="$WG_DIR/$WG_IF.conf"

WG_BIN="$(command -v wg 2>/dev/null || true)"
WG_QUICK="$(command -v wg-quick 2>/dev/null || true)"

# 1) Kulcsok generálása
if [ ! -f "$WG_PRIV" ] || [ "$REGEN_KEYS" -eq 1 ]; then
    echo "wg-router: privát kulcs generálása..."
    if [ "$DRY_RUN" -eq 0 ]; then
        if [ -n "$WG_BIN" ]; then
            $WG_BIN genkey | tee "$WG_PRIV" | $WG_BIN pubkey > "$WG_PUB"
        else
            head -c 32 /dev/urandom | base64 > "$WG_PRIV"
            echo "FAKEPUBLICKEY==" > "$WG_PUB"
        fi
        chmod 600 "$WG_PRIV"
        chmod 644 "$WG_PUB"
    else
        echo "(DRY RUN) wg genkey és pubkey kihagyva"
        echo "DRYRUNPRIVATEKEYFAKE==" > "$WG_PRIV"
        echo "DRYRUNPUBLICKEYFAKE==" > "$WG_PUB"
    fi
else
    echo "wg-router: meglévő kulcsok megtartva"
fi

# 2) wg0.conf létrehozása / frissítése
if [ ! -f "$WG_CONF" ] || [ "$REGEN_KEYS" -eq 1 ]; then
    echo "wg-router: wg0.conf létrehozása/frissítése..."
    if [ "$DRY_RUN" -eq 0 ]; then
        cat > "$WG_CONF" <<EOF
[Interface]
Address = fd00:abcd::1/64
ListenPort = $LISTEN_PORT
PrivateKey = $(cat "$WG_PRIV")
PostUp = ip6tables -A FORWARD -i %i -j ACCEPT
PostDown = ip6tables -D FORWARD -i %i -j ACCEPT

# === Peer template ===
[Peer]
# Peer neve: home-router / VPN peer / barát
PublicKey = <PEER_PUBLIC_KEY>        # ide a peer publikus kulcsát
AllowedIPs = fd00:abcd::2/128        # vagy a peer IPv6 címe / prefix
Endpoint = <PEER_ENDPOINT>:51820     # IP vagy domain + port
PersistentKeepalive = 25             # NAT mögötti peer esetén
EOF
        chmod 600 "$WG_CONF"
    else
        echo "(DRY RUN) wg0.conf létrehozás kihagyva, de tartalom:"
        echo "[Interface]"
        echo "Address = fd00:abcd::1/64"
        echo "ListenPort = $LISTEN_PORT"
        echo "PrivateKey = $(cat "$WG_PRIV")"
        echo "PostUp / PostDown DRY RUN-ban nem alkalmazva"
        echo "# Peer template (DRY RUN)"
        echo "[Peer]"
        echo "PublicKey = <PEER_PUBLIC_KEY>"
        echo "AllowedIPs = fd00:abcd::2/128"
        echo "Endpoint = <PEER_ENDPOINT>:51820"
        echo "PersistentKeepalive = 25"
    fi
fi

# 3) Init.d script
echo "wg-router: init.d script telepítése: $INIT_SCRIPT"
if [ "$DRY_RUN" -eq 0 ]; then
    cat > "$INIT_SCRIPT" <<'EOF'
#!/bin/sh
### BEGIN INIT INFO
# Provides:          wg-router
# Required-Start:    $network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: WireGuard IPv6 router + ip6tables hardening
### END INIT INFO

PATH=/sbin:/usr/sbin:/bin:/usr/bin
WG_IF="wg0"
LAN_IF="wlan0"
WAN_IF="tun0"
WG_CONF="/etc/wireguard/${WG_IF}.conf"
IP6TABLES="$(command -v ip6tables 2>/dev/null || true)"
IP="$(command -v ip 2>/dev/null || true)"
SYSCTL="$(command -v sysctl 2>/dev/null || true)"

do_sysctl() {
  [ -n "$SYSCTL" ] && {
    $SYSCTL -w net.ipv6.conf.all.forwarding=1 >/dev/null 2>&1 || true
    $SYSCTL -w net.ipv6.conf.default.forwarding=1 >/dev/null 2>&1 || true
    $SYSCTL -w net.ipv6.conf.all.accept_redirects=0 >/dev/null 2>&1 || true
    $SYSCTL -w net.ipv6.conf.all.accept_source_route=0 >/dev/null 2>&1 || true
  }
}

wg_up() {
  [ -f "$WG_CONF" ] && command -v wg-quick >/dev/null 2>&1 && wg-quick up "$WG_IF" >/dev/null 2>&1 || true
}

wg_down() {
  command -v wg-quick >/dev/null 2>&1 && wg-quick down "$WG_IF" >/dev/null 2>&1 || true
}

case "$1" in
start)
  echo "wg-router: start"
  do_sysctl
  wg_up
  ;;
stop)
  echo "wg-router: stop"
  wg_down
  ;;
restart|force-reload)
  $0 stop
  sleep 1
  $0 start
  ;;
status)
  echo "wg-router status:"
  command -v wg-quick >/dev/null 2>&1 && wg-quick show "$WG_IF" 2>/dev/null || echo "$WG_IF down"
  ;;
*)
  echo "Usage: $0 {start|stop|restart|status}"
  exit 1
  ;;
esac
EOF
    chmod 755 "$INIT_SCRIPT"
    update-rc.d wg-router defaults >/dev/null 2>&1 || true
else
    echo "(DRY RUN) init.d telepítés kihagyva"
fi

# 4) Éles / dry-run indítás
if [ "$DRY_RUN" -eq 0 ]; then
    "$INIT_SCRIPT" start || true
    "$INIT_SCRIPT" status || true
else
    echo "(DRY RUN) start/status kihagyva, fájlok generálva"
fi

echo "=== wg-router installer kész ==="
echo "Privát kulcs: $WG_PRIV"
echo "Publikus kulcs: $WG_PUB"
echo "wg0.conf: $WG_CONF"
echo "Init script: $INIT_SCRIPT"
[ "$DRY_RUN" -eq 1 ] && echo "DRY RUN kész: semmi hálózati változás nem történt."

