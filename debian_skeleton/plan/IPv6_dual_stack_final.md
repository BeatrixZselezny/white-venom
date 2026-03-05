# White-Venom: Dual-Stack & Phase 1 IPv6 Defense Plan (v2.2-stable)

## 1. Stratégiai Célkitűzés
[cite_start]A White-Venom motor kiterjesztése az IPv6 szállítási protokollra, különös tekintettel a **Link-Local (fe80::/10)** alapú támadási felületekre[cite: 271, 282]. [cite_start]A cél a tanulmány szerinti **Phase 1 (Discovery)** láthatóvá tétele és blokkolása a Zero-Trust elvek mentén[cite: 278, 281].

---

## 2. Hitelesített Router Identitás (Identity-Aware Shield)
A rendszer az IPv4-nél már bevált MAC-alapú hitelesítést terjeszti ki az IPv6 Neighbor Discovery-re (NDP).

* **Anchor Pont:** Az `/etc/venom/router.identity` fájlban tárolt MAC cím szolgál egyedüli bizalmi forrásként.
* **BPF Validáció:** A kernel-szintű szűrő (venom_shield.bpf) összeveti az ICMPv6 Router Advertisement (RA) forrás MAC címét a regisztrált identitással.
* [cite_start]**Phase 1 Blokkolás:** Minden olyan NDP vagy RA üzenet, amely nem a hitelesített routertől származik, azonnali `DROP` ágra kerül a kernelben[cite: 278, 292].

---

## 3. Hardening és Konfiguráció (ConfigTemplates.cpp)
[cite_start]A hálózati stack sterilizálása az "Invisible IPv6" mítoszának felszámolásával[cite: 273, 319]:

* [cite_start]**Láthatóság fenntartása:** `ipv6.disable=0` és `disable_ipv6=0` – nem vakítjuk el a rendszert, hanem monitorozzuk[cite: 281, 303].
* **RA Kontroll:** `net.ipv6.conf.all.accept_ra=0` (alapértelmezett tiltás), a legális forgalmat a BPF engedélyezi szelektíven.
* [cite_start]**Protokoll Tisztítás:** A `6lowpan`, `sit`, `tunnel6` modulok végleges tiltása a **Phase 2 (Propagation)** megakadályozására[cite: 280, 298].

---

## 4. Core Idegrendszer: StreamProbe & Bus
[cite_start]Az IPv6-specifikus entrópiás mérés és osztályozás[cite: 74]:

* [cite_start]**DataType Bővítés:** `ICMPV6` és `IPV6_HEADER` típusok bevezetése az analízishez[cite: 76].
* [cite_start]**Dinamikus Küszöb:** Ha a szonda `fe80::` vagy `ff02::` mintát észlel, a $Threshold_{dynamic}$ értéket automatikusan szigorítja (Morzsika-szűrő)[cite: 55, 80].
* [cite_start]**Metabolizmus:** Az IPv6 csomagfeldolgozás költségei beépülnek a `loadFactor` számításba[cite: 161, 162].

---

## 5. Implementációs Sorrend (Holnapi ütemterv)

### Fázis 0: Alapozás (Reggel)
1. [cite_start]**`TelemetryTypes.hpp` & `TelemetrySnapshot.hpp`**: Új számlálók az IPv6 eseményekhez[cite: 169, 175].
2. **`BpfLoader.hpp`**: A hitelesített MAC cím átadása a kernel-space felé.

### Fázis 1: Hardening (Délelőtt)
3. [cite_start]**`ConfigTemplates.cpp`**: IPv6 sysctl és blacklist szabályok élesítése[cite: 193].
4. [cite_start]**`StreamProbe.cpp`**: v6-tudatos Zero-Trust logika beépítése[cite: 83, 84].

### Fázis 2: UI & BPF (Délután)
5. **`main.cpp`**: A Dual-Stack Dashboard és a `secureSetupRouter` kiterjesztése.
6. **`venom_shield.bpf.c`**: A MAC-alapú RA szűrés implementálása.

---
**Status:** READY FOR SYNC | **Maintainer:** Beatrix Zselezny | **System State:** DUAL-STACK-STEALTH
