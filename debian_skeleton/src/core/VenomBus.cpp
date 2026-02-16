// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework - Core Component (Fixed Compilation)

#include "core/VenomBus.hpp"
#include "core/Scheduler.hpp"
#include "core/StreamProbe.hpp"
#include "core/NullScheduler.hpp"
#include <iostream>
#include <vector>
#include <cmath>
#include <algorithm>

namespace Venom::Core {

    VenomBus::VenomBus() {
        telemetry.reset_window();
    }

    void VenomBus::pushEvent(const std::string& source, const std::string& data) {
        telemetry.total_events++;
        telemetry.queue_depth++;
        
        if (telemetry.queue_depth > 1000) {
            telemetry.null_routed_events++;
            telemetry.queue_depth--;
            return;
        }

        vent_bus.get_subscriber().on_next(VentEvent{source, data});
    }

    void VenomBus::startReactive(rxcpp::composite_subscription& lifetime, const Scheduler& scheduler) {
        auto raw_stream = vent_bus.get_observable();

        // Közvetlen feliratkozás a pair-mentes, stabil működésért
        raw_stream
            .subscribe_on(rxcpp::observe_on_new_thread())
            .observe_on(rxcpp::observe_on_new_thread())
            .subscribe(lifetime, [this, &scheduler](VentEvent ev) {
                // Dinamikus entrópiás küszöb számítása
                auto meta = telemetry.get_metabolism();
                double dynamicThreshold = 6.8 * (1.0 / (meta.loadFactor + 0.11));
                
                double entropy = StreamProbe::calculateEntropy(ev.payload);
                
                // Eldöntjük a sorsát: WC vagy Elfogadva
                if (entropy > dynamicThreshold) {
                    // WC (Null-Routing)
                    NullScheduler::absorb(ev);
                    telemetry.null_routed_events++;
                } else {
                    // Értékes adat
                    telemetry.accepted_events++;
                }
                
                if (telemetry.queue_depth > 0) telemetry.queue_depth--;
            });
            
        std::cout << "[VenomBus] Adaptív pipeline élesítve (Pair-free stable). 🐍" << std::endl;
    }

    TelemetrySnapshot VenomBus::getTelemetrySnapshot() const {
        return telemetry.snapshot();
    }

} // namespace Venom::Core
