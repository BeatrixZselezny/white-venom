# Dual-Venom Architecture: Asynchronous Twin-Bus Model
**Dátum:** 2026.01.27.
**Status:** Draft / Implementation Plan
**Kontextus:** White Venom Hardening Framework (C++ Port)
**Hivatkozott dokumentumok:** 1. Stream Expectation & Scheduler Routing Specification
2. Time-Cube Profiling – Venom Scheduler Security Model

## 1. Vezetői Összefoglaló
A jelenlegi rendszer (`Scheduler.cpp` loop) szinkron működése blokkolja a végrehajtást az adatfeldolgozás alatt. Ez lehetetlenné teszi a precíz időmérést (Time-Cube) és a DoS elleni védelmet. A megoldás a **Dual-Venom** architektúra, amely RxCpp alapokon szétválasztja a rendszert egy "Szellőztető" (adat) és egy "Agykéreg" (vezérlés) rétegre.

---

## 2. Architektúra: The Twin-Bus System

A `VenomBus` osztályt átalakítjuk egy **Facade** mintává, amely két belső, izolált RxCpp `Subject`-et kezel.

### 2.1. The Vent (Szellőztető) - Data Plane
* [cite_start]**Forrás:** `Stream Expectation Spec` [cite: 60]
* **Szerepe:** A külvilágból érkező, megbízhatatlan adatfolyamok fogadása.
* **Concurrency:** `rxcpp::schedulers::make_event_loop()` (Worker Thread Pool).
* **Működés:**
    1.  **Input:** Nyers események (Log sorok, FileSystem események).
    2.  [cite_start]**Probe:** `StreamProbe` futtatása (könnyűsúlyú elemzés)[cite: 51].
    3.  [cite_start]**Routing:** Döntés a `StreamExpectation` alapján (Normal/High/Null)[cite: 61].
    4.  [cite_start]**Fail-safe:** Ha a pool megtelik, a `NullScheduler` minden további adatot eldob[cite: 73].

### 2.2. The Cortex (Agykéreg) - Control Plane
* [cite_start]**Forrás:** `Time-Cube Profiling` [cite: 101]
* **Szerepe:** Belső állapotok, biztonsági döntések és időmérés.
* **Concurrency:** `rxcpp::schedulers::make_new_thread()` (Dedikált, sorosított szál).
* **Működés:**
    1.  Csak validált, tiszta "SecurityCommand" objektumokat fogad.
    2.  [cite_start]**Time-Cube mérés:** Mivel ez a szál sosem blokkolódik IO-val, itt mérjük a modulok relatív idejét[cite: 104].
    3.  **Execution:** Itt történik a `SafeExecutor` hívások engedélyezése.

---

## 3. RxCpp Implementációs Terv

A jelenlegi `std::vector<IBusModule>` helyett reaktív stream-eket építünk.

### 3.1. Új Típusdefiníciók (Headerterv)

```cpp
// A nyers adatcsomag a Vent buszon
struct RawEvent {
    DataType type;          // [cite: 13]
    std::vector<uint8_t> payload;
    size_t timestamp;
};

// A feldolgozott parancs a Cortex buszon
struct SecurityCommand {
    std::string moduleName;
    std::string action;
    PrivilegeContext context;
};
```

## 3.2. A Busz Logika (Pseudocode)
A VenomBus inicializálásakor felépítjük a pipeline-t:

```cpp
// 1. VENT BUS (Input)
auto vent_stream = rxcpp::subjects::subject<RawEvent>();

// 2. CORTEX BUS (Control)
auto cortex_stream = rxcpp::subjects::subject<SecurityCommand>();

// 3. ÖSSZEKÖTÉS (Routing Logic)
vent_stream.get_observable()
    .observe_on(rxcpp::schedulers::make_event_loop()) // Párhuzamos worker szálak
    .map([](RawEvent e) {
        return StreamProbe::analyze(e); // [cite: 50]
    })
    .filter([](ProbeResult r) {
        // Stream Expectation szűrés
        if (r.is_malformed || r.rate > LIMIT) {
            // NullScheduler logika: csendes eldobás [cite: 76]
            return false;
        }
        return true;
    })
    .map([](ProbeResult r) {
        return convertToCommand(r);
    })
    .observe_on(rxcpp::schedulers::make_new_thread()) // Átadás a Cortex szálnak
    .subscribe(cortex_stream.get_subscriber());
    ```

## 4. Migrációs Lépések (Roadmap)
Fázis 1: Előkészítés (Infrastructure)

- RxCpp integrálása: A Makefile és include path-ok beállítása.
- Model osztályok: StreamProbe, StreamExpectation struktúrák létrehozása a specifikációk alapján.

Fázis 2: The Vent (Input réteg)

- A jelenlegi IBusModule átalakítása IReactiveSource-ra.
- A VenomBus::runAll() ciklus lecserélése az RxCpp subscription-re.

Fázis 3: The Cortex (Logic réteg)

- A Scheduler.cpp while(running) ciklusának kiváltása a Cortex thread-del.
- A Time-Cube logika implementálása a Cortex stream operátoraiként (timestamp mérések két esemény között).

Fázis 4: Dispatcher Refactor

- A dispatchCommand függvény átírása, hogy ne közvetlenül hívja a SafeExecutor-t, hanem egy SecurityCommand-ot dobjon a Cortex buszra.

## 5. Security Posture Outcome

Ez az architektúra biztosítja:

- Determinisztikus időzítés: A Cortex szálat nem zavarja a hálózati zaj.
- Burst tolerancia: A Vent worker threadjei elnyelik a hirtelen terhelést.
- Silent Drop: A támadó nem kap visszajelzést (Null Scheduler).

