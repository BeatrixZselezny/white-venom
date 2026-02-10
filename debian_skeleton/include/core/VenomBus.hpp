// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#ifndef VENOM_BUS_HPP
#define VENOM_BUS_HPP

#include <memory>
#include <string>
#include "rxcpp/rx.hpp"

// Alapvető típusok és szondák
#include "core/StreamProbe.hpp"     // Szükséges a DataType enum miatt
#include "telemetry/BusTelemetry.hpp"
#include "TimeCubeTypes.hpp"

namespace Venom::Core {

    class Scheduler; // Forward declaration

    /**
     * @brief Esemény típus a Vent buszon (Nyers adat) [cite: 3]
     */
    struct VentEvent {
        std::string source;
        std::string payload;
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
     * Feladata a stream osztályozása és determinisztikus irányítása. [cite: 4, 61]
     */
    class VenomBus {
    private:
        // --- The Twin Buses ---
        rxcpp::subjects::subject<VentEvent> vent_bus;
        rxcpp::subjects::subject<CortexCommand> cortex_bus;

        // --- Infrastructure ---
        BusTelemetry telemetry;
        TimeCubeBaseline timeCubeBaseline;

    public:
        VenomBus();
        
        // Nyers adat betolása (Thread-safe)
        void pushEvent(const std::string& source, const std::string& data);
        
        // A reaktív pipeline elindítása [cite: 91]
        void startReactive(rxcpp::composite_subscription& lifetime, const Scheduler& scheduler);

        // Diagnosztika
        [[nodiscard]] TelemetrySnapshot getTelemetrySnapshot() const;
    };
}

#endif
