// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#ifndef VENOM_BUS_HPP
#define VENOM_BUS_HPP

#include <memory>
#include <string>
#include <atomic>
#include <mutex>
#include "rxcpp/rx.hpp"

#include "core/StreamProbe.hpp"
#include "telemetry/BusTelemetry.hpp"
#include "TimeCubeTypes.hpp"

namespace Venom::Core {

    class Scheduler;

    struct VentEvent {
        std::string source;
        std::string payload;
        bool isArp; // Új: ARP-specifikus jelző
    };

    struct CortexCommand {
        std::string targetModule;
        std::string action;
    };

    class VenomBus {
    private:
        rxcpp::subjects::subject<VentEvent> vent_bus;
        rxcpp::subjects::subject<CortexCommand> cortex_bus;

        BusTelemetry telemetry;
        TimeCubeBaseline timeCubeBaseline;

        mutable std::mutex ip_mutex;
        std::string last_filtered_ip;

    public:
        VenomBus();
        
        // Kibővített pushEvent az ARP támogatáshoz
        void pushEvent(const std::string& source, const std::string& data, bool isArp = false);
        void startReactive(rxcpp::composite_subscription& lifetime, const Scheduler& scheduler);

        [[nodiscard]] TelemetrySnapshot getTelemetrySnapshot() const;
        [[nodiscard]] std::string getLastFilteredIP() const;
    };
}

#endif
