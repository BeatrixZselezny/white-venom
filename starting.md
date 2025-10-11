Király — ez nagyon erős irány: **AppArmor / SELinux hardening** + minimal Debian + Fluxbox = profi, defense‑in‑depth rendszer. Átadok egy **gyakorlati, MD-formátumú tervet**: döntési segéd, telepítési és tesztelési lépések, konkrét példák AppArmor‑profilra és SELinux policy‑modulra, valamint rollback/CI javaslatok. Másold be a repódba `HARDENING-LSM.md` néven.

---

# LSM Hardening: AppArmor & SELinux — terv és gyakorlat (Debian)

**Cél:** megvédeni a fejlesztői stack-et (PostgreSQL, Java/Spring, Maven, dev tools) LSM‑profilokkal anélkül, hogy a fejlesztés menetéhez túlzott frictiont adnánk.
**Követelmény:** biztonságos, visszaállítható, tesztelhető pipeline; rollback lehetőség.

> Röviden: **válassz egy LSM-et (AppArmor vagy SELinux)** a production/desktop gépedre. Mindkettőt egyszerre használni nem érdemes (bonyolult, kompatibilitási problémák). Debianon **AppArmor** az alapértelmezett (könnyebb), SELinux erősebb, de invazívabb.

---

## 1) Döntési segéd

* **AppArmor** — Debian default, egyszerűbb profilkészítés (aa-genprof), jó desktop/dev gépre, könnyebb debugolni.
  Ajánlott, ha: gyors felfuttatás, könnyű iteráció, WSL2/dev gép → később prod-on is folytatható.

* **SELinux** — durvábban szabályoz, finomabb MAC, sok vállalati környezetben elvárás.
  Ajánlott, ha: céges szabvány SELinux, erős izoláció kell, hajlandó vagy több időt szánni a fejlesztésre (fájl‑labeling, policy‑írás).

**Javaslat:** otthoni/dev gépen kezd AppArmor‑ral, majd ha később a nagy deployment SELinuxot követel, írjuk át a profilokat policy‑vá. Most adok AppArmor‑first lépéseket + SELinux quick‑guide‑t.

---

## 2) Alap telepítés / előkészület (Debian)

### AppArmor (alap)

```bash
# telepítés / ellenőrzés
sudo apt update
sudo apt install apparmor apparmor-utils
sudo systemctl enable --now apparmor

# státusz
sudo aa-status
```

### SELinux (opcionális, ha váltasz)

> Debian: `selinux-basics` és policy csomagok; *invazívabb*, reboot szükséges, fájlrendszer labeling kell.

```bash
sudo apt install selinux-basics selinux-policy-default auditd
sudo selinux-activate   # beállítja a rendszert, reboot kell
# reboot után
getenforce   # Enforcing / Permissive / Disabled
```

---

## 3) Általános hardening lépések (mindkettőre érvényes)

1. **Inventory** — listázd a védendő folyamatokat: `postgres`, `java -jar myapp.jar`, `mvn`, `sshd`, `docker` stb.
2. **Minimal privileges** — minden folyamat annyi jogot kapjon, amennyi szükséges (least privilege).
3. **Audit first** — kezdetben működtess permissive / complain módot, gyűjts denials‑t.
4. **Iteratív tighten** — naplózás → elemzés → szabályok szigorítása → élesítés.
5. **Backup & rollback** — profilok, policy‑k és rtl‑backup előtti snapshot/export.

---

## 4) AppArmor: gyors workflow + példa profil

### 4.1 Generálás (iteratív)

```bash
# Indítsd a szolgáltatást complain módban (gyűjti az eseményeket)
sudo aa-complain /usr/bin/java   # vagy a futtatható fájl útvonala

# Használd az appot, futtasd az összes funkciót -> naplózás gyűlik
sudo journalctl -f | grep apparmor

# Profil generálás interaktív: aa-genprof
sudo aa-genprof /usr/bin/java
# Kövesd az utasításokat; a generált profil /etc/apparmor.d/*-java
```

### 4.2 Példa: egyszerű profil egy Spring Boot JAR-hez

Mentsd: `/etc/apparmor.d/usr.bin.my-spring-app` (vagy a distro szabályai szerint)

```text
# Profile for my Spring Boot app (java -jar /opt/myapp/app.jar)
#include <tunables/global>

/opt/myapp/app.jar {
  # alap jogok
  /opt/myapp/app.jar r,
  /opt/myapp/** r,
  /etc/myapp/** r,
  /var/log/myapp/** rw,
  /tmp/** rw,
  /dev/** r,
  /usr/bin/java mr,        # read & mmap for java bin (ha futtatod ezzel)
  capability net_bind_service,    # ha 80/443 portot bindolsz
  network inet stream,
  network inet6 stream,
  # MPL: mappold ki a pontos fájlokat, amiket kell
}
```

**Flow:** `aa-genprof` sokat segít, majd `aa-enforce /etc/apparmor.d/usr.bin.my-spring-app` élesíthető.

### 4.3 Denials vizsgálata

```bash
sudo journalctl -k | grep apparmor
# vagy
sudo dmesg | grep apparmor
# log elemzése: aa-logprof is segít
sudo aa-logprof
```

---

## 5) SELinux: gyors bevezetés és példa policy‑modul

### 5.1 Bevezetés (permissive → audit)

```bash
# Telepítés és aktiválás (Debian)
sudo apt install selinux-basics selinux-policy-default auditd policycoreutils
sudo selinux-activate
# Reboot szükséges; utána:
sudo setenforce 0    # permissive (audit), ne azonnal enforcing módba tedd
```

### 5.2 Fájlok címkézése

Minden futtatható és adatfájl SELinux címkéket kell, hogy kapjon:

```bash
# példa: applikáció könyvtárának címkézése
sudo semanage fcontext -a -t usr_t '/opt/myapp(/.*)?'
sudo restorecon -Rv /opt/myapp
```

### 5.3 Egyszerű policy példa (modul)

`myapp.te`:

```text
module myapp 1.0;

require {
    type unconfined_t;
    class file { read execute open };
    class tcp_socket name_bind;
    class process transition;
}

# Engedélyezés: read+exec a /opt/myapp/app.jar
allow unconfined_t usr_t:file { read execute open };
allow unconfined_t self:process transition;
# Ha portot bindol:
allow unconfined_t port_t:tcp_socket name_bind;
```

Létrehozás és betöltés:

```bash
checkmodule -M -m -o myapp.mod myapp.te
semodule_package -o myapp.pp -m myapp.mod
sudo semodule -i myapp.pp
```

> Valódi SELinux policy írás sok finomhangolást igényel. Kezdetben futtasd permissive módban, gyűjts audit naplókat (`ausearch`, `audit2allow`).

### 5.4 Auditból policy generálása

```bash
# keress denials-t
ausearch -m avc -ts recent
# javasolt allow sorok generálása
audit2allow -a -M myapp_generated
sudo semodule -i myapp_generated.pp
```

---

## 6) Specifikus javaslatok a te stackedhez

### PostgreSQL

* AppArmor: használj hivatalos/konkret profilokat (`/etc/apparmor.d/usr.lib.postgresql.*`), korlátozd adatkönyvtárra való hozzáférést.
* SELinux: `postgresql_exec_t`, `postgresql_db_t` típusok megfelelő használata; adatkönyvtár címkézése.

### Java / Spring / Maven

* AppArmor: profil engedélyezze a `~/.m2` cache olvasást/írást, `java` bin hozzáférést, hálózati socketeket csak a szükséges portokra (bind esetén).
* SELinux: JAR és munkakönyvtár címkézése, `http_port_t` ha 80/443, vagy saját port típus létrehozása.

### Docker / container runtimes

* Containers → külön profilok. AppArmor profilok konténerekre (Docker használ `docker-default`). SELinux integráció: `container_t` típusokat használd és engedélyezd a szükséges bindmountokat.

---

## 7) Tesztelés, CI és rollback

* **Local dev**: minden profil permissive/complain módban fusson 24–72 óráig, gyűjts logokat.
* **CI**: unit teszt futtatás a profil mögött (pl. GitHub Actions runner VM‑en AppArmor‑ral) — reprodukálható tesztkörnyezet.
* **Rollback**: profil élesítés előtt mentés:

  * AppArmor: `cp /etc/apparmor.d/usr.bin.my-spring-app /root/backup/`
  * SELinux: `semodule -l > /root/selinux-modules.list` és `semanage fcontext -l > fcontext.backup`
* **Emergency**: ha valami eltörik, visszaállítás:

  * AppArmor: `sudo aa-complain /etc/apparmor.d/<profile>` vagy `sudo systemctl stop apparmor` (utolsó resort).
  * SELinux: `sudo setenforce 0` (permissive), majd debug.

---

## 8) Monitoring és alerting

* `auditd` + `ausearch`, `aureport` a SELinux esetén.
* `journalctl -k` és `aa-logprof`, `aa-notify` AppArmorhoz.
* SIEM integráció (ELK/EFK/Splunk) a deny eseményekre.
* Riasztás: high‑severity denials → Slack/email.

---

## 9) Konkrét next steps (sorban, amit most csinálj)

1. **Válaszd ki**: AppArmor (ajánlott kezdéshez) vagy SELinux.
2. **Inventory készítése**: `ps aux` → határozd meg a védendő folyamatokat.
3. **Enable AppArmor** és állítsd `complain` módra a célprocs‑t. (pl. `aa-complain /usr/bin/java`)
4. **Futtasd a szolgáltatásokat**: használd, terheld, futtasd a teszteket 24–72 óráig.
5. **Gyűjts logokat** és futtass `aa-genprof` → generáld a profilokat.
6. **Teszteld élesben** egy non‑production VM‑en `enforce` módban.
7. **CI integráció**: PR‑eknél futtass sandboxed teszteket.
8. **Élesítés**: ha stabil, élesítsd, monitorozz.

---

## 10) Ha akarod, megírom neked konkrét profilokat

* AppArmor profil a Spring Boot JAR‑edre (teljes, pontos `/opt/myapp/` fájlokkal) — **most rögtön megcsinálom**, ha megadod a pontos futtatási parancsot és adatútvonalakat (`jar path`, `log path`, `config path`, portok).
* SELinux `.te` modul a PostgreSQL + Java kombinációdhoz (ha SELinuxot választod).

Mondd: **AppArmor‑ral kezdjük** és adj meg néhány pontos útvonalat (pl. `/opt/myapp/app.jar`, PostgreSQL adat könyvtár `/var/lib/postgresql/14/main`, maven cache `~/.m2`) — és megírom az első, működő AppArmor profilt, amivel 24–72 órát gyűjthetsz auditot.
