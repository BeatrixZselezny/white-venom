# 🐍 Hydra Addendum: "Visual Memory" Module (The Watchman)

**Koncepció:** Az elavult, lista-alapú feketelista-kezelés (O(N)) kiváltása konstans idejű (O(1)) valószínűségi felismerővel.

## 1. A Probléma: "List-Fatigue"
A hagyományos feketelisták (Blacklists) méretének növekedésével a keresési idő lineárisan nő. Publikus interfészen egy DDoS támadás során a lista böngészése önmagában CPU-túlterhelést (exhaustion) okozhat, mielőtt a kígyó egyáltalán "harapna".

## 2. A Megoldás: Bit-Map "Ránézésre" (Bloom Filter)
A Hydra nem listákat olvas, hanem egy **Visual Memory** bit-táblát használ az IP-k felismerésére.

### 2.1. Működési elv
- **Ujjlenyomatvétel:** Amikor egy IP kitiltásra kerül, 3-5 különböző hash függvény generál bit-indexeket.
- **Felismerés:** Beérkező csomag esetén a processzor csak a megadott bit-helyeket ellenőrzi a memóriában.
- **Sebesség:** Fix O(1). Nem számít, hogy 10 vagy 10 millió IP-t tartunk nyilván, a felismerés sebessége azonos (CPU bit-művelet).

## 3. Technikai Specifikáció

| Jellemző | Hagyományos Lista | Hydra Visual Memory |
| :--- | :--- | :--- |
| **Keresési idő** | O(N) (Lassuló) | **O(k) (Konstans / Azonnali)** |
| **Memóriaigény** | Magas (Sztringek) | **Alacsony (Fix bit-array)** |
| **Hamis Negatív** | Lehetséges | **Lehetetlen (100% biztonság)** |
| **Hamis Pozitív** | Nincs | Minimális (<0.01%, a StreamProbe korrigálja) |

## 4. Reaktív Integráció (The L0 Gate)
A `VenomBus` legelső szűrője (L0) nem engedi az adatot a hálózati pufferbe, ha a Visual Memory "kőrözött" arcot lát:

```cpp
// Pseudocode - The Watchman Logic
auto ingress = raw_stream
    .filter([](const HydraEvent& e) {
        return !VisualMemory::is_on_wanted_list(e.source_ip); // Nanosec check
    })
    .subscribe(venom_bus_input);
