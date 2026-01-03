
# Debian Security Hardening Bootstrap
## Repository: white-venom


SecurityDebian-bootstrap hardening with orchectrator.

## Cél

Ez a projekt egy shell-alapú bootstrap script, amely Debian 11/12 rendszerek biztonsági keményítését végzi el. A cél a minimális támadási felület kialakítása, alapértelmezett szolgáltatások auditálása, és a rendszer viselkedésének kiszámíthatóvá tétele.

## Funkciók

- SSH konfiguráció keményítése:
  - `PermitRootLogin no`
  - `PasswordAuthentication no`
  - `MaxAuthTries`, `LoginGraceTime`, `AllowUsers` beállítások
- `sysctl` kernel security paraméterek:
  - Kernel
  - Networking
  - FS
- `auditd` telepítése és alapértelmezett szabályok betöltése
- Mamória védelem - Canary
- Strict minimal install (pl. `telnet`, `rsh`, `xinetd`)
- Dpkg-APT minimalizált hardening
- Journald és logrotate konfiguráció megerősítése
- Alapértelmezett tűzfal (iptables/nftables) szabályok inicializálása
- DNS hardening QUAD9
- NTP hardening, szoftveres és hardveres óra biztonsági konfiguráció

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

A projekt a mellékelt LICENSE.md fájlban található egyedi EULA feltételei szerint használható. Kereskedelmi felhasználása szigorúan tilos.

**Kereskedelmi célú felhasználás, értékesítés vagy integráció fizetős szolgáltatásba tilos.**
