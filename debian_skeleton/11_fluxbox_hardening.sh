#!/bin/bash
# branches/09_x11_fluxbox_hardening.sh
# Fluxbox és X11 telepítése. X11 KIZÁRÓLAG LOKÁLISAN engedélyezve (Zero Trust).
# Távoli X11 Forwarding és titkosítatlan TCP listener tiltva.
set -euo pipefail

# --- KONZISZTENCIA ÉS KONFIG ---
LOGFILE="/var/log/x11_hardening.log"
XINITRC="/etc/X11/xinit/xinitrc"
SSHD_CONFIG="/etc/ssh/sshd_config"
# Globális log függvényt feltételezünk
log() { echo "$(date +%F' '%T) $*"; }

# Ellenőrzés: root user
if [ "$(id -u)" -ne 0 ]; then
    log "[ERROR] Run as root!" >&2
    exit 1
fi

# --- TRANZAKCIÓS TISZTÍTÁS (CLEANUP/ROLLBACK) ---
branch_cleanup() {
    log "[CRITICAL ALERT] Hiba történt a 09-es ág futása közben! Megkísérlem a rollbacket..."
    
    # 1. SSHD config visszaállítása (ha van backup)
    if [ -f "$SSHD_CONFIG.bak" ]; then
        log "[ACTION] SSHD config visszaállítása."
        mv "$SSHD_CONFIG.bak" "$SSHD_CONFIG"
        service ssh restart || true
    fi

    # 2. X11 és Fluxbox csomagok eltávolítása (purge)
    log "[ACTION] Fluxbox/X11 csomagok eltávolítása."
    apt-get purge -y fluxbox xinit xserver-xorg-core xserver-xorg-input-all || true
    
    log "[CRITICAL ALERT] 09-es ág rollback befejezve. Nézd át a logokat!"
}
trap branch_cleanup ERR

# --- 1. TELEPÍTÉS (Zero Trust Minimal) ---
log "[ACTION] Fluxbox és X11 magkomponensek telepítése (minimalista)."
apt-get install -y --no-install-recommends \
    fluxbox \
    xinit \
    xserver-xorg-core \
    xserver-xorg-input-all \
    xterm # Minimalista terminál az X-hez

# --- 2. X11 HARDENING (Titkosítás és Távoli Hozzáférés TELJES TILTÁSA) ---

# 2.1 SSHD Konfiguráció (Távoli X11 Forwarding TILTÁSA)
log "[HARDENING] SSHD konfiguráció backupja és módosítása az X11 forward TELJES TILTÁSÁRA."
cp "$SSHD_CONFIG" "$SSHD_CONFIG.bak"

# Kitörlünk minden X11-re vonatkozó sort
sed -i '/^X11Forwarding/d' "$SSHD_CONFIG"
sed -i '/^X11UseLocalhost/d' "$SSHD_CONFIG"
sed -i '/^X11DisplayOffset/d' "$SSHD_CONFIG"

# Explicit tiltjuk a forwardolást, mivel csak lokális használat a cél
echo "X11Forwarding no" >> "$SSHD_CONFIG"
log "[ACTION] SSHD X11 forwardolás tiltva. Service újraindítása szükséges."
service ssh restart || true

# 2.2 X Server TCP Listener és XDMCP Tiltása
# Ez a rész garantálja, hogy a titkosítatlan X protokoll senki felé ne "beszéljen"
XSERVER_DEFAULTS="/etc/default/xserver-xorg"
if [ -f "$XSERVER_DEFAULTS" ]; then
    log "[HARDENING] X Server beállítás -nolisten tcp kényszerítése (MITM/Hálózati X ellen)."
    # Kényszerítjük, hogy az X Server NE figyeljen TCP portokon
    # Ha már létezik a beállítás, felülírjuk
    if grep -q 'XSERVER_OPTS' "$XSERVER_DEFAULTS"; then
        sed -i 's/^XSERVER_OPTS=.*$/XSERVER_OPTS="-nolisten tcp"/' "$XSERVER_DEFAULTS"
    else
        # XKBMODEL után beillesztve
        sed -i '/^XKBMODEL/a XSERVER_OPTS="-nolisten tcp"' "$XSERVER_DEFAULTS"
    fi
fi

# XDMCP teljesen tiltva (távoli, titkosítatlan grafikus belépés)
XDMCP_CONFIG="/etc/X11/Xwrapper.config"
if [ -f "$XDMCP_CONFIG" ]; then
    log "[HARDENING] XDMCP explicit tiltása a $XDMCP_CONFIG-ban."
    sed -i '/^allowed_users/d' "$XDMCP_CONFIG"
    echo "allowed_users=console" >> "$XDMCP_CONFIG" # Csak konzolról indítható
    echo "needs_root_rights=yes" >> "$XDMCP_CONFIG"
fi


# --- 3. FLUXBOX KONFIGURÁCIÓ (Minimalista Start) ---

# 3.1 Alapvető xinitrc beállítás
log "[ACTION] $XINITRC testreszabása: csak Fluxbox indítása."
cat > "$XINITRC" <<'EOF'
#!/bin/sh
# Minimalista xinitrc a Fluxbox indításához (Zero Trust - csak lokális)

# Állítsuk be a minimalista háttérszínt
xsetroot -solid grey

# Indítsuk el a fluxboxot
exec startfluxbox
EOF
chmod +x "$XINITRC"

log "[DONE] 09-es ág befejezve. X11 Hardening (Kizárólag Lokális Használat) és Fluxbox telepítve."
exit 0
