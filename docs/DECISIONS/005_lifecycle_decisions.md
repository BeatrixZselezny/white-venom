# 005 – Életciklus Döntések (Lifecycle Decisions)
**Dátum:** 2025-11-30
**Státusz:** Aktív
**Kategória:** Rendszerarchitektúra / Bootstrap pipeline

---

## LD-01 – A GRUB-injektálás áthelyezése a 00_install modulba

**Indoklás:**
A GRUB kernelparaméterek injektálása túl későn történt (02_ szinten), amikor már userland komponensek megkezdhették a futást.
 A kernelvédelmi beállításoknak a rendszerindítás legelső szakaszában kell érvényre jutniuk.

**Döntés:**
A korábbi `02_grub_inject.sh` archiválásra került, a teljes logika beolvadt a `00_install.sh` modulba.

---

## LD-02 – Kötelező sysctl-lockdown fázis bevezetése

**Indoklás:**
Az IPv4 redirect-alapú támadások, illetve több LPE technika csak akkor zárható ki, ha a kernel networking és filesystem védelmei
 már az első ms-okban aktívak. Ez APT, DNS, vagy bármilyen hálózati művelet előtt kötelező.

**Döntés:**
A `00_whitevenom_bootstrap.conf` már a bootstrap korai szakaszában települ, lezárva a kritikus kernel-változókat.

---

## LD-03 – Környezeti változók sanitizálása

**Indoklás:**
A root-shell örökli a felhasználói környezetet, amely LD_PRELOAD, PATH, TMPDIR vagy IFS manipulációval kompromittálható
 (ENV-based privilege escalation). A teljes környezet sterilizálása kötelező bootstrap előfeltétel.

**Döntés:**
A 00_install első műveleteként végrehajtásra kerül az ENV-sanitizálás (PATH fixálás, LD_* törlés, IFS reset, TMPDIR rögzítése).

---

## LD-04 – A White Venom kanonikus 7-lépcsős bootstrapje

**Indoklás:**
A projekt folyamatos bővülése szükségessé tette egy egységes, determinisztikus telepítési pipeline rögzítését.
 A korábbi modulok nem garantálták a helyes sorrendet.

**Döntés:**
A teljes bootstrap 7 atomikus fázisra oszlik:

1. Környezet sterilizálása
2. Sysctl lockdown
3. GRUB environment baseline
4. APT + toolchain telepítés
5. ldconfig sanity-check
6. Alap rendszerkönyvtárak létrehozása
7. Canary marker

Ez a sorrend kötelező és rögzített.

---

## LD-05 – Elavult modulok archiválása

**Indoklás:**
Biztonsági és traceability okok miatt a kivezetett vagy átszervezett modulokat nem töröljük végleg — szükség esetén visszakereshetők.

**Döntés:**
Minden kivezetett modul (pl. a régi 02_grub_inject) a `parking/` könyvtárba kerül archiválásra.


