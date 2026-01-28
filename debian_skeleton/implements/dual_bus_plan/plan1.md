# Dual-Venom Architecture: Asynchronous Twin-Bus Model
**Dátum:** 2026.01.27.
**Status:** Draft / Implementation Plan
**Kontextus:** White Venom Hardening Framework (C++ Port)

## 1. Vezetői Összefoglaló
A jelenlegi egyszálú (single-thread) működés biztonsági kockázatot jelent: egy nagyméretű vagy komplex payload elemzése blokkolhatja a fő végrehajtási szálat, így a rendszer "vakká" válhat a kritikus Time-Cube ablakokban. 

A megoldás a **Dual-Venom (Iker-Busz)** architektúra, amely szétválasztja a nyers adatfeldolgozást (Data Plane) és a biztonsági döntéshozatalt (Control Plane).

---

## 2. Architektúra Áttekintés

A rendszer két, egymástól izolált RxCpp buszon (Subject) kommunikál, eltérő prioritással és ütemezéssel.

### 2.1. The Vent (Szellőztető) - Data Plane
Ez a rendszer "külvilág felé néző" interfésze.
* **Felelősség:** Nyers események (inotify, netlink, log stream) fogadása és előszűrése.
* **Concurrency Modell:** `Worker Thread Pool` (Párhuzamos feldolgozás).
* **Működése:**
    1.  Fogadja a `RawStream` adatot.
    2.  [cite_start]Lefuttatja a **Stream Probe**-ot (könnyűsúlyú mintavételezés)[cite: 51].
    3.  [cite_start]A **Stream Expectation** szabályok alapján [cite: 26] dönt a routingról.
* [cite_start]**Fail-safe:** Ha a Thread Pool telítődik, a rendszer automatikusan **NULL Scheduler** módba vált[cite: 73], és minden további csomagot azonnal, feldolgozás nélkül eldob.

### 2.2. The Cortex (Agykéreg) - Control Plane
Ez a rendszer "belső idegrendszere".
* **Felelősség:** Állapotgépek kezelése, Time-Cube mérések, Modulok koordinációja.
* **Concurrency Modell:** `Serialized / Single Dedicated Thread` (Sorosított végrehajtás).
* **Működése:**
    * Csak a "Vent" által megtisztított, validált metaadatokat fogadja.
    * Itt nincsenek nehéz IO műveletek, csak memória-műveletek és állapot-átmenetek.
    * Ez garantálja, hogy a biztonsági logika (Lockdown, Profil-váltás) sosem blokkolódik.

---

## 3. Integráció a Biztonsági Modellekkel

### 3.1. Time-Cube Profiling Integráció
[cite_start]A "Cortex" busz dedikált szála teszi lehetővé a precíz **Time-Cube** méréseket[cite: 103].
* [cite_start]Mivel a Cortex sosem blokkolódik IO-val, a modulok futási ideje determinisztikus marad[cite: 108].
* A rendszer a saját "belső idejét" méri a feladatok között, így a terheléses támadások (amik a Vent buszt érintik) nem torzítják el a belső időreferenciát.

### 3.2. Stream Expectation Routing
[cite_start]A "Vent" busz implementálja a determinisztikus routingot az elvárások (Expectation) alapján[cite: 61]:
* **Input:** Bejövő adatfolyam (pl. JSON, TEXT, BINARY).
* [cite_start]**Probe:** A StreamProbe elemzi az adat típusát és rátáját[cite: 52].
* **Decision:**
    * *Matches Normal Profile:* Továbbítás a Cortex felé (feldolgozásra).
    * [cite_start]*Matches High Profile:* Továbbítás vagy eldobás (állapottól függően)[cite: 63].
    * [cite_start]*Matches None / Malformed:* Azonnali irányítás a **NullScheduler**-be[cite: 67].

---

## 4. Implementációs Stratégia (C++ / RxCpp)

### 4.1. Busz Definíciók
```cpp
// Data Plane (Vent) - Párhuzamos feldolgozás
auto vent_scheduler = rxcpp::schedulers::make_event_loop();
auto vent_bus = rxcpp::subjects::subject<RawDataEvent>();

// Control Plane (Cortex) - Dedikált, sorosított szál
auto cortex_scheduler = rxcpp::schedulers::make_new_thread();
auto cortex_bus = rxcpp::subjects::subject<SecurityCommand>();
