
# Debian Security Hardening Bootstrap
## Repository: white-venom


Automatizált rendszerkeményítés Debian-alapú környezetekhez.

## Cél

Ez a projekt egy shell-alapú bootstrap script, amely Debian 11/12 rendszerek biztonsági keményítését végzi el. A cél a minimális támadási felület kialakítása, alapértelmezett szolgáltatások auditálása, és a rendszer viselkedésének kiszámíthatóvá tétele.

## Funkciók

- SSH konfiguráció keményítése:
  - `PermitRootLogin no`
  - `PasswordAuthentication no`
  - `MaxAuthTries`, `LoginGraceTime`, `AllowUsers` beállítások
- `sysctl` kernel paraméterek:
  - IP forwarding tiltása
  - ICMP redirect-ek tiltása
  - Source routing tiltása
  - TCP SYN cookies engedélyezése
- `auditd` telepítése és alapértelmezett szabályok betöltése
- Felesleges csomagok és szolgáltatások eltávolítása (pl. `telnet`, `rsh`, `xinetd`)
- Journald és logrotate konfiguráció megerősítése
- Fail2ban előkonfiguráció SSH brute force elleni védelemhez
- Alapértelmezett tűzfal (iptables/nftables) szabályok inicializálása
- DNS és NTP forgalom explicit engedélyezése (opcionális whitelistelés)

## Használat

```bash
curl -s https://raw.githubusercontent.com/<user>/debian-hardening-bootstrap/main/bootstrap.sh | bash
```


**Figyelem:** A script root jogosultságot igényel. Minden lépés logolva van, és visszavonható.

## Rendszerkövetelmények

- Debian 11 vagy 12 (tesztelve: bullseye, bookworm)
- bash, curl, apt, systemd alapértelmezett környezet
- Internetkapcsolat a csomagok letöltéséhez

##  Naplózás

A script minden lépése naplózva van a következő helyen:

```
/var/log/debian-hardening-bootstrap.log
```

## Tesztelés

A scriptet LXC konténerben és KVM-alapú virtuális gépen teszteltem. A változtatások nem igényelnek újraindítást, kivéve ha sysctl paraméterek vagy szolgáltatás újrakonfigurálása ezt megköveteli.

## Kiterjesztési lehetőségek

- CIS Benchmark megfelelés (baseline szint)
- Ansible playbook verzió
- CI/CD pipeline-ba integrálható audit modul

## Licenc

Ez a projekt a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)](https://creativecommons.org/licenses/by-nc-sa/4.0/) licenc alatt érhető el.

Ez azt jelenti, hogy:

- A tartalom szabadon másolható, módosítható és terjeszthető **nem kereskedelmi célra**
- A szerző (white-venom) nevét minden felhasználásnál fel kell tüntetni
- Módosított verziók csak ugyanezen licenc alatt terjeszthetők

**Kereskedelmi célú felhasználás, értékesítés vagy integráció fizetős szolgáltatásba tilos.**