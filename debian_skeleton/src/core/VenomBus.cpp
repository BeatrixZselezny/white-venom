#include "core/VenomBus.hpp"
#include "core/Scheduler.hpp"
#include "core/StreamProbe.hpp"
#include "core/NullScheduler.hpp"
#include <iostream>

namespace Venom::Core {

    VenomBus::VenomBus() {
        telemetry.reset_window();
        last_filtered_ip = "";
    }

    void VenomBus::pushEvent(const std::string& source, const std::string& data, bool isArp) {
        telemetry.total_events++;
        telemetry.queue_depth++;
        
        if (telemetry.queue_depth > 1000) {
            telemetry.null_routed_events++;
            telemetry.queue_depth--;
            return;
        }

        vent_bus.get_subscriber().on_next(VentEvent{source, data, isArp});
    }

    void VenomBus::startReactive(rxcpp::composite_subscription& lifetime, const Scheduler& scheduler) {
        (void)scheduler;
        auto raw_stream = vent_bus.get_observable();

        raw_stream
            .window_with_time(std::chrono::milliseconds(200))
            .subscribe_on(rxcpp::observe_on_new_thread())
            .subscribe(lifetime, [this](rxcpp::observable<VentEvent> window) {
                window.subscribe([this](VentEvent ev) {
                    auto meta = telemetry.get_metabolism();
                    double dynamicThreshold = 6.8 * (1.0 / (meta.loadFactor + 0.11));
                    double entropy = StreamProbe::calculateEntropy(ev.payload);
                    
                    if (entropy > dynamicThreshold || ev.isArp) {
                        NullScheduler::absorb(ev);
                        telemetry.null_routed_events++;
                        
                        std::lock_guard<std::mutex> lock(ip_mutex);
                        last_filtered_ip = ev.source;
                    } else {
                        telemetry.accepted_events++;
                    }
                    
                    if (telemetry.queue_depth > 0) telemetry.queue_depth--;
                });
            });
            
        std::cout << "[VenomBus] Reaktív ablakozás élesítve (200ms Trixie-Sync). 🐍" << std::endl;
    }

    TelemetrySnapshot VenomBus::getTelemetrySnapshot() const {
        return telemetry.snapshot();
    }

    std::string VenomBus::getLastFilteredIP() const {
        std::lock_guard<std::mutex> lock(ip_mutex);
        return last_filtered_ip;
    }
}
