// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#ifndef VENOM_BUS_HPP
#define VENOM_BUS_HPP

#include <memory>
#include <string>
#include "rxcpp/rx.hpp"

// Telemetria és Típusok
#include "telemetry/BusTelemetry.hpp"
#include "TimeCubeTypes.hpp"

namespace Venom::Core {

    // Forward declaration a Schedulerhez
    class Scheduler;

    /**
     * @brief Esemény típus a Vent buszon (Nyers adat)
     */
    struct VentEvent {
        std::string source;
        std::string payload;
        // Később bővíthetjük a StreamProbe adatokkal
    };

    /**
     * @brief Parancs típus a Cortex buszon (Validált akció)
     */
    struct CortexCommand {
        std::string targetModule;
        std::string action;
    };

    /**
     * @brief Ring 1: Dual-Venom Bus Controller
     * Facade pattern: elrejti a két belső Rx buszt a külvilág elől.
     */
    class VenomBus {
    private:
        // --- The Twin Buses ---
        
        // 1. The Vent (Input/Data Plane)
        rxcpp::subjects::subject<VentEvent> vent_bus;

        // 2. The Cortex (Control/Logic Plane)
        rxcpp::subjects::subject<CortexCommand> cortex_bus;

        // --- Telemetry ---
        BusTelemetry telemetry;
        TimeCubeBaseline timeCubeBaseline;

    public:
        VenomBus();
        
        // --- Public API (Publishing) ---
        
        // Nyers adat betolása a rendszerbe (pl. inotify által)
        void pushEvent(const std::string& source, const std::string& data);

        // --- Lifecycle Management ---
        
        // A Scheduler hívja meg, hogy felépítse a reaktív láncot (pipeline)
        void startReactive(rxcpp::composite_subscription& lifetime, const Scheduler& scheduler);

        // --- Diagnostics ---
        [[nodiscard]] TelemetrySnapshot getTelemetrySnapshot() const;
    };
}

#endif
