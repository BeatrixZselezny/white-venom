# Venom RX - Network Stack Hardening (Modul 27)

## Technikai Specifikáció
A hálózati stack védelme nem alkalmazás-szintű, hanem közvetlen kernel-beavatkozás (sysctl/routing). Cél a botnetek és portscanerek eliminálása a TCP flag-ek szűrésével.

## Tiltott TCP Flag-ek
- **RST (Reset):** Tiltva. Belső IPC (Busz/DB) `FIN` lezárást használ. Az `RST` anomália.
- **PSH (Push):** Tiltva. Localhost (lo) látenciája mellett funkcionálisan szükségtelen (RFC 9293).
- **URG (Urgent):** Tiltva. Elavult (Legacy), modern stack nem használja. Kizárólag támadási vektor.

## Mérnöki Konklúzió
- Nincs RFC kényszer a PSH/URG/RST használatára belső kommunikációban.
- A szűrés routing szinten történik: zéró overhead, zéró alkalmazás-függőség.
- A localhost (lo) interfészre is kiterjesztve (Zero-Trust).

## PoC (Proof of Concept) Audit
Mielőtt a szabályok bekerülnek a release-be, auditálni kell a futó rendszer forgalmát:

```bash
#!/bin/bash
# venom_net_audit.sh
# Monitorozza a 'lo' forgalmat a tiltandó flagekre.

if ! command -v tcpdump >/dev/null 2>&1; then
    echo "Hiba: tcpdump szükséges."
    exit 1
fi

echo "[*] Audit indítása (lo)..."
tcpdump -i lo 'tcp[tcpflags] & (tcp-push|tcp-urg|tcp-rst) != 0' -nn -vv
```

## Implementációs lépések (Debian: The Simple Way)
- RP Filter: net.ipv4.conf.all.rp_filter=1 (Spoofing védelem).
- RFC 1337: net.ipv4.tcp_rfc1337=1 (RST-assassination védelem).
-Blackhole Routing: Gyanús flag-kombinációk irányítása a semmibe (ip route add blackhole).

