## Telepítés + használat

Másold be:

```bash
sudo cp verify_apt_integrity.sh /usr/local/sbin/
sudo chmod +x /usr/local/sbin/verify_apt_integrity.sh
```

Első futtatás:

```bash
sudo verify_apt_integrity.sh
```

Ez létrehozza az alap hash adatbázist.

Ha később tudatosan módosítod az /etc/apt fájlokat, frissítheted a baseline-t:

```bash
sudo find /etc/apt -type f -exec sha256sum {} \; > /var/lib/apt_conf.hashes
```

(Opcionális) Időzítés hetente egy dry-check-kel:

```bash
sudo bash -c 'echo "0 4 * * 1 root /usr/local/sbin/verify_apt_integrity.sh >/dev/null 2>&1" >> /etc/crontab'
```

### Első futtatásnál javasolt log-ellenőrzés:

```bash
# Első futtatás után érdemes ellenőrizni a logot:
sudo tail -n 20 /var/log/apt_integrity.log
```

Így látod, hogy minden rendben ment-e, és egyből látható a [OK] vagy [!] státusz.

### “Gyors visszaállítás” (pl. ha valaki véletlenül törli a baseline-t):

Ha elveszett vagy sérült a baseline hash adatbázis:
```bash
sudo rm -f /var/lib/apt_conf.hashes
sudo verify_apt_integrity.sh
```
Ez újra létrehozza a referencia hash-eket az aktuális /etc/apt állapot alapján.

> 💡 Ez a script nemcsak az APT integritását ellenőrzi, hanem a systemd-csomagok jelenlétét is, és figyelmeztet, ha valaki “véletlenül” visszatelepítené.


