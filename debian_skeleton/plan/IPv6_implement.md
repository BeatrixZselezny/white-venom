# White-Venom: IPv6 Implementációs Terv (v2.2-draft)

## 1. Stratégiai Célkitűzés
[cite_start]A White-Venom motor kiterjesztése az IPv6 szállítási protokollra, fenntartva a **Zero-Trust** alapelveket és a **Metabolism-Aware** dinamikus védelmi mechanizmust[cite: 1, 11]. A cél a dual-stack üzemmód teljes körű hardeningje és monitorozása.

---

## 2. Hardening és Konfiguráció (ConfigTemplates)
[cite_start]Az IPv6-specifikus védelmi vonalak beépítése a `VenomTemplates` névtérbe[cite: 204]:

### 2.1. Kernel Hardening (sysctl)
[cite_start]A `SYSCTL_BOOTSTRAP_CONTENT` bővítése az alábbiakkal[cite: 195]:
* **RA Korlátozás:** `net.ipv6.conf.all.accept_ra=0` (Router Advertisement üzenetek tiltása a spoofing ellen).
* **Privacy Extensions:** `net.ipv6.conf.all.use_tempaddr=2` (Ideiglenes címek kényszerítése az adatvédelemért).
* **Hop Limit:** `net.ipv6.conf.all.hop_limit=128` (Konzisztens TTL/Hop limit az OS fingerprinting nehezítésére).

### 2.2. Protokoll Tiltás (Blacklist)
[cite_start]A `BLACKLIST_CONTENT` kiterjesztése az IPv6-on belüli szükségtelen alprotokollokra[cite: 198]:
* `install /bin/true` alkalmazása a `6lowpan`, `ipv6_tunnel` és `sit` modulokra, amennyiben nem indokolt a használatuk.

---

## 3. Core Idegrendszer Fejlesztések

### 3.1. StreamProbe: IPv6 Analízis
[cite_start]A `StreamProbe` osztály felkészítése az új típusú forgalom osztályozására[cite: 74]:
* [cite_start]**DataType bővítés:** `ICMPV6` és `IPV6_HEADER` típusok bevezetése[cite: 76].
* [cite_start]**Entrópia mérés:** Az IPv6 fix, 40 bájtos fejlécének statisztikai ellenőrzése a `calculateEntropy` metódussal[cite: 78].
* [cite_start]**Zero-Trust szűrés:** Ha a szonda Neighbor Discovery flood-ot vagy gyanús Extension Header-eket észlel, az eseményt azonnal a `NullScheduler`-be irányítja[cite: 58, 84].



[Image of IPv6 header structure]


### 3.2. VenomBus és Telemetria
* [cite_start]**Metabolikus hatás:** Az IPv6 hálózati események sűrűsége beépül a `loadFactor` számításba[cite: 161, 162].
* [cite_start]**Dinamikus küszöb:** A $Threshold_{dynamic} = 6.8 \times (1.0 / (loadFactor + 0.1))$ képlet alkalmazása az IPv6-specifikus bemenetekre is[cite: 55].

---

## 4. Végrehajtó Modulok (SafeExecutor & Utils)

### 4.1. SafeExecutor és ip6tables
* [cite_start]Új szabályok regisztrálása az `ExecPolicyRegistry`-ben az `/usr/sbin/ip6tables` bináris számára[cite: 210].
* [cite_start]**Szemantikai validáció:** A `validate` callback kiterjesztése az IPv6 címformátumok (pl. tömörített `::1`) ellenőrzésére[cite: 209].

### 4.2. HardeningUtils: IPv6 Sterilizálás
* [cite_start]**FSTAB Hardening:** Az `/etc/fstab` ellenőrzésekor az IPv6-alapú hálózati csatolások (pl. NFSv4 over IPv6) `nosuid,nodev` zászlóinak kényszerítése[cite: 225].
* [cite_start]**String Sanitization:** A `StringUtils` felkészítése a kettőspontokkal tagolt IPv6 címek biztonságos kezelésére a konfigurációs fájlok írásakor[cite: 229].

---

## 5. Implementációs Sorrend (Protocol Zero szerint)
1. [cite_start]**Fázis 0:** `TimeCubeTypes.hpp` és `TelemetryTypes.hpp` bővítése az új hálózati metrikákkal[cite: 181, 169].
2. [cite_start]**Fázis 1:** `ConfigTemplates.cpp` frissítése a fenti sysctl szabályokkal[cite: 193].
3. [cite_start]**Fázis 2:** `StreamProbe.cpp` logikájának módosítása az IPv6 detektáláshoz[cite: 74].
4. [cite_start]**Fázis 3:** `ExecPolicyRegistry` inicializálása az `ip6tables` irányelvekkel[cite: 213].

---
**Status:** DRAFT | **Version:** v2.2-ipv6-dev | **Compliance:** Zero-Trust Protocol
