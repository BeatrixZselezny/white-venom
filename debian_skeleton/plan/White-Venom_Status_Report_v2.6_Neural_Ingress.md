# 🐍 White-Venom Framework - Neural Ingress Jelentés v2.6

## 🎯 Stratégiai Bővítés: Az Érzékelés és Elemzés
A rendszer a kernel-szintű védelem mellett megkapta a User Space-beli mélyebb elemző képességeket. A cél a "Zero-Trust Ingress", ahol minden beérkező stream-et viselkedési és informatikai entrópia alapján osztályozunk.

---

## 🧬 Új Komponensek és Funkciók

### 1. SocketProbe (Zero-Trust Ingress)
* **Forrás**: `SocketProbe.cpp`, `SocketProbe.hpp`
* **Működés**: Egy nem-blokkoló (non-blocking) TCP szerver, amely a 8888-as porton (vadászterület) fogadja a forgalmat.
* **Reaktív lánc**: A beérkező nyers adatokat aszinkron módon továbbítja a `VenomBus`-ra, biztosítva, hogy a hálózati figyelés ne akassza meg a rendszer többi részét.

### 2. StreamProbe (Viselkedési és Entrópia Analízis)
* **Forrás**: `StreamProbe.cpp`, `StreamProbe.hpp`
* **Shannon-entrópia**: Kiszámítja az adatfolyam belső rendezettségét, segítve a titkosított vagy bináris zaj felismerését.
* **Zero-Trust Osztályozás**: 
    * Megkülönbözteti a `TEXT`, `JSON`, `METRIC` és `BINARY` típusokat.
    * **Dinamikus küszöb**: `HIGH` profil esetén szigorúbb (5.8) entrópia-határt alkalmaz a bináris adatok kiszűrésére.

### 3. Scheduler (Központi Idegrendszer)
* **Forrás**: `Scheduler.cpp`, `Scheduler.hpp`
* **Hídképzés**: Összeköti a `VisualMemory`-t és a `BpfLoader`-t. Amint egy entitás eléri a 3. tüskét (strike), a Scheduler automatikusan leküldi az IP-t a kernel `blacklist_map`-jébe.
* **Domain szegregáció**: Három külön ütemezőt kezel:
    * `Vent`: Gyors, reaktív események.
    * `Cortex`: Mélyelemzés és döntéshozatal.
    * `Null`: Eseményelnyelés visszacsatolás nélkül.

---

## 📊 Összegzett Rendszer-Fiziológia
* **Detekció**: eBPF (Kernel) + StreamProbe (User Space).
* **Memória**: Bloom-filter alapú `VisualMemory`.
* **Végrehajtás**: Azonnali kernel-szintű blokkolás a 200ms-os szelektív telemetria-ablak figyelembevételével.

## 💀 Tervezési alapelv
"Bad input does not break the system - it is simply ventilated out." – A rendszer immunitása az öntudaton és a csendes elnyelésen (NullScheduler) alapul.
