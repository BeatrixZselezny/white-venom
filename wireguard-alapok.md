# WireGuard – Gyors jegyzetek

## Mi az a WireGuard?
Egy modern, minimalista, UDP-alapú VPN, a Linux kernelbe integrálva.

## Titkosítás
- Curve25519 kulcsok
- ChaCha20 stream cipher
- Poly1305 MAC

## Csomagvesztés és UDP
A csomagok külön vannak titkosítva, UDP-n továbbítva. A TCP-t a VPN alagúton belül az alkalmazások biztosítják.

## Példa config
```ini
[Interface]
PrivateKey = <privát kulcs>
Address = 10.0.0.2/32
DNS = 9.9.9.9

[Peer]
PublicKey = <szerver publikus kulcs>
Endpoint = vpn.example.com:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25


