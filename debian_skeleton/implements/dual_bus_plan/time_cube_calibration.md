# Time-Cube Profiling: Relative Reference System (The Venom Tick)
**Dátum:** 2026.01.27.
**Status:** Design Draft
**Kontextus:** White Venom Hardening Framework
**Kapcsolódó specifikáció:** Time-Cube Profiling – Venom Scheduler Security Model

## 1. A Probléma
[cite_start]A Time-Cube modell alapelve, hogy a védelem nem külső időbélyegekre (wall-clock), hanem belső, rendszer-specifikus időreferenciákra épül[cite: 105, 108].
Azonban a rögzített időkorlátok (pl. "500ms") nem működőképesek, mert:
* A hardverek sebessége eltérő.
* A rendszer terheltsége dinamikusan változik.
* Egy CPU-igényes frissítés alatt a rendszer lelassulhat, ami téves "Time-Cube" sértést (High Profile váltást) okozna.

## 2. Megoldás: A "Venom Tick" Referencia Egység
Bevezetünk egy absztrakt, relatív időegységet, a **Venom Tick**-et.
A rendszer nem milliszekundumokban, hanem Tick-ekben méri az elvárásokat.

$$T_{várható} = Költség_{tick} \times \text{RendszerSebesség}$$

### 2.1. A Rendszer Sebesség (System Metabolism)
A `VenomInitializer` minden induláskor (és a `Scheduler` periodikusan) lefuttat egy **Mikro-Benchmarkot**.
* **Feladat:** Egy fix, CPU-intenzív művelet (pl. 10MB memória SHA256 hash-elése vagy fix számú mátrixszorzás).
* **Eredmény:** A művelet végrehajtási ideje milliszekundumban. Ez az aktuális **1 Tick** hossza.

### 2.2. Golden Run (Kalibrációs Fázis)
Telepítéskor vagy a `venom --calibrate` parancs kiadásakor a rendszer "Tanuló Módba" lép.
1.  Lefuttatja a Mikro-Benchmarkot (Referencia Tick rögzítése).
2.  Lefuttatja az összes modult (pl. `FilesystemModule`, `InitSecurityModule`) üres/teszt terheléssel.
3.  Kiszámolja és eltárolja a modulok "árát" Tick-ben.

> **Példa:**
> * Benchmark ideje: 100ms (1 Tick = 100ms).
> * `FilesystemModule` futása: 500ms.
> * **Tárolt Költség:** 5.0 Tick.

### 2.3. Runtime (Éles Üzem)
Amikor a rendszer élesben fut, és a CPU terhelt:
1.  A Scheduler méri az aktuális "anyagcserét": A Benchmark most **200ms** (a rendszer lassabb).
2.  A `FilesystemModule` elindításakor a rendszer kiszámolja a megengedett ablakot:
    * $5.0 \text{ Tick} \times 200\text{ms} = 1000\text{ms}$.
3.  Ha a modul 800ms alatt fut le, az **Time-Cube szempontból elfogadható**, bár abszolút időben lassabb volt a kalibráltnál.

---

## 3. Implementációs Terv

### 3.1. Adatstruktúrák (`TimeCubeTypes.hpp`)

```cpp
struct TimeCubeBaseline {
    double referenceTickMs; // A kalibráláskori 1 Tick hossza
    std::map<std::string, double> moduleCostInTicks; // Modulok "ára"
};

struct SystemMetabolism {
    double currentTickMs; // Jelenlegi rendszersebesség
    double loadFactor;    // current / reference arány
};
```

## Teszt kód
3. Implementációs Terv

- Ez bekerülhet a utils/HardeningUtils.hpp-ba vagy a core/Scheduler.hpp-ba.

```cpp
struct TimeCubeBaseline {
    double unitBenchmarkMs; // A "Venom Tick" hossza ms-ban kalibráláskor
    std::map<std::string, double> moduleCosts; // Modulok költsége "Tick"-ben
};

class TimeCubeProfiler {
public:
    // Mikro-benchmark futtatása az aktuális CPU sebesség mérésére
    static double measureSystemSpeed();

    // Kalibrációs futás: minden modult lemér és elmenti a Baseline-t
    void calibrate(const std::vector<std::shared_ptr<IBusModule>>& modules);

    // Visszaadja, hogy az aktuális rendszerterhelés mellett mennyi a várható futási idő
    double getExpectedDurationMs(const std::string& moduleName, double currentSystemSpeed);
};
```

## 3.2. Calibration Manager (CalibrationManager.cpp)

```cpp
class CalibrationManager {
public:
    // A "Metronóm": fix számítási igényű feladat
    static double runMicroBenchmark() {
        auto start = std::chrono::high_resolution_clock::now();
        // ... CPU intenzív számítás (pl. volatile loop) ...
        auto end = std::chrono::high_resolution_clock::now();
        return std::chrono::duration<double, std::milli>(end - start).count();
    }

    // A Golden Run végrehajtása
    void performCalibration(VenomBus& bus) {
        double refTick = runMicroBenchmark();
        // Modulok futtatása és mérése...
        // Eredmény mentése: /var/lib/venom/time_cube.bin
    }
};
```
## 3.3. Integráció a Schedulerrel

A Cortex busz (vezérlő szál) a feladatok kiosztásakor (dispatch) ellenőrzi az időkeretet.

- Ha ActualTime > (ExpectedTicks * CurrentTickMs * Tolerance), akkor:
- Ez Time-Cube Violation.
- Gyanús aktivitás -> Profil eszkaláció (Normal -> High).
- A lassulás nem a rendszer általános terheléséből fakad (azt a Tick kompenzálta), hanem az adott modul rendellenes viselkedéséből.

## 4. Security Előnyök

    Anti-Timing Analysis: A támadó nem tudja kívülről megtippelni az időkorlátokat, mert azok a rendszer pillanatnyi állapotától függenek.

Load Tolerance: A rendszer nem tilt le hamis pozitívval csak azért, mert elindult egy backup folyamat a háttérben.

Anomaly Detection: Képes megkülönböztetni a "lassú gépet" a "megtámadott modultól".

