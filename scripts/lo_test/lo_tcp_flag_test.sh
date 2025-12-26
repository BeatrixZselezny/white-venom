#!/bin/bash
# Venom RX - Network Traffic Audit Tool
# Cél: Monitorozni a 'lo' forgalmát a tiltandó flagekre.

INTERFACE="lo"
LOG_FILE="/tmp/venom_net_audit.log"

echo "[*] Venom RX - Hálózati Audit indítása a(z) $INTERFACE interfészen..."
echo "[*] Figyelt flagek: RST, PSH, URG"
echo "[*] Eredmények mentése: $LOG_FILE"

# Tcpdump segítségével figyeljük a flag-kombinációkat (ha telepítve van)
# Ha nincs, a kernel logot (dmesg) fogjuk figyelni a későbbiekben.
if command -v tcpdump >/dev/null 2>&1; then
    tcpdump -i $INTERFACE 'tcp[tcpflags] & (tcp-push|tcp-urg|tcp-rst) != 0' -nn -vv | tee -a $LOG_FILE
else
    echo "[!] Hiba: tcpdump nem található. Kérlek telepítsd: apt install tcpdump"
    exit 1
fi
