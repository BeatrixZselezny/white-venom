// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework
// Time-Cube Types: The internal relative reference system

#ifndef TIMECUBE_TYPES_HPP
#define TIMECUBE_TYPES_HPP

#include <string>
#include <unordered_map>
#include <chrono>

// Telemetria típusok integrálása a konzisztencia érdekében
#include "telemetry/TelemetryTypes.hpp"

namespace Venom::Core {

    /**
     * @brief A rendszer "anyagcseréjének" pillanatnyi állapota.
     * Ez a titkos szorzó, amit a támadó nem láthat.
     */
    struct SystemMetabolism {
        // A referencia (kalibrációs) Tick hossza milliszekundumban
        double referenceTickMs;
        
        // A jelenlegi (terhelt) Tick hossza milliszekundumban
        double currentTickMs;

        // Terhelési faktor (Current / Reference). 
        // Ha > 1.0, a rendszer lassú, tehát a moduloknak több idő jár.
        double loadFactor;
    };

    /**
     * @brief Egyetlen modul "Fekete Doboz" profilja.
     * A külső világ számára láthatatlan paraméterek.
     */
    struct ModuleTimeProfile {
        std::string moduleName;

        // --- Time-Cube Konfiguráció (Static / Calibrated) ---
        
        // A modul "ára" Tick-ben (nem ms-ben!).
        // Ez hardverfüggetlen állandó.
        double expectedCostTicks;

        // A megengedett szórás (Variance). 
        // Szigorú moduloknál (pl. crypto) kicsi, IO moduloknál nagyobb.
        double toleranceSigma;

        // --- Runtime Telemetria (Dynamic) ---

        // Utolsó mért futási idő ms-ben (debug/trace célra)
        double lastDurationMs;
        
        // Hányszor sértette meg a Time-Cube-ot? 
        // (Használhatjuk a TelemetryTypes-ból is, ha ott van specifikus Counter)
        uint32_t violationCount;
    };

    /**
     * @brief A teljes rendszer "Time-Cube" lenyomata.
     * Ez a fájl (time_cube_baseline.bin) a rendszer "ujjlenyomata".
     */
    struct TimeCubeBaseline {
        // Mikor készült a kalibráció?
        std::chrono::system_clock::time_point calibrationDate;
        
        // A kalibrációs Tick hossza (pl. 100ms)
        double baseTickMs;

        // Modul név -> Profil összerendelés
        // A sorrendet a map nem tárolja, az a Scheduler logikájában rejtőzik.
        std::unordered_map<std::string, ModuleTimeProfile> profiles;
    };

} // namespace Venom::Core

#endif // TIMECUBE_TYPES_HPP
