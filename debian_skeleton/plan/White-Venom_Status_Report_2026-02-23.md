# 🐍 White-Venom Security Framework - Állapotjelentés v2.4

## 🎯 Jelenlegi Architektúra Áttekintése

A rendszer egy többszintű, hibrid védelmi modellt valósít meg, amely ötvözi a kernel-szintű kíméletlen végrehajtást (eBPF/XDP) és a User Space intelligens, energiatakarékos memóriakezelését.

---

## 🛠️ Megvalósított Komponensek (Source Audit)

### 1. Végrehajtó Réteg (Kernel - eBPF/XDP)
* **Forrás**: `venom_shield.bpf.c`
* **Technológia**: XDP (eXpress Data Path), amely közvetlenül a hálózati kártya illesztőprogramjánál operál.
* **Funkciók**:
    * **L2 szűrés**: Ethernet keretek vizsgálata IP protokollra.
    * **Blacklist Enforcer**: `blacklist_map` (Hash Map) alapján történő azonnali csomageldobás (`XDP_DROP`).
    * **Statisztikai modul**: Atomi számlálók (`stats_map`) az összes és az eldobott forgalom követésére.

### 2. Intelligens Memória (User Space - Visual Memory)
* **Forrás**: `VisualMemory.cpp`, `VisualMemory.hpp`
* **Technológia**: 1 MB méretű atomi bit-tömbön alapuló Bloom-filter.
* **Logika**:
    * **Energiahatékonyság**: Gyors predikció a gyanús entitásokról anélkül, hogy nehézkes listákban kellene keresni.
    * **Three Spike Szabály**: IP-alapú incidensszámláló (`strike_count`). A 3. tüske (strike) elérésekor automatikusan aktiválja a blokkolási parancsot.

### 3. Vezérlő Híd (User Space - BpfLoader)
* **Forrás**: `BpfLoader.cpp`, `BpfLoader.hpp`
* **Funkciók**:
    * **Deploy**: Libbpf segítségével betölti és az interfészhez (pl. `wlo1`) csatolja a kernel kódot.
    * **Map Managament**: Kezeli a kernel és user space közötti adatátvitelt (pl. `blockIP` hívás a blacklist frissítéséhez).

---

## 🛰️ Jövőbeli Terv: "Tűpontos Reaktív Látás"

A cél a passzív statisztika-kiolvasás (polling) lecserélése egy aszinkron, eseményvezérelt adatfolyamra.

### 🐍 Telemetria Szekvencia (RxCpp)
1. **Emitter**: A kernel program (`venom_shield.bpf.c`) módosítása, hogy tiltáskor egyedi EtherType (pl. `0x9999`) csomagot lökjön ki a használt interfészre.
2. **Observable**: Az `rxcpp` könyvtár segítségével egy Raw Socket figyelő létrehozása, amely a telemetriai kereteket "befogja".
3. **Data Stream**: A dashboard nem kérdez, hanem "hallgat" (Observe); az adatok csak akkor érkeznek, ha esemény van, így a CPU használat minimális marad.

---

## 💀 Megjegyzés a Cíberpunk Esztétikához
A rendszer jelenlegi állapota igazolta az ARP-mérgezés elleni védelmet (Router MAC validáció előkészítve a `BpfLoader`-ben). A 100 000+ eldobott csomag után a következő mérföldkő a "Kaszás" reaktív visszajelzése a Dashboard-on (💀🛰️❤️).
