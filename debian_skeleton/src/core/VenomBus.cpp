// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#include "core/VenomBus.hpp"
#include "core/Scheduler.hpp"
#include "core/StreamProbe.hpp"
#include "core/NullScheduler.hpp"
#include <iostream>
#include <vector>

namespace Venom::Core {

    VenomBus::VenomBus() {
        telemetry.reset_window();
    }

    void VenomBus::pushEvent(const std::string& source, const std::string& data) {
        telemetry.total_events++;
        telemetry.queue_depth++;
        vent_bus.get_subscriber().on_next(VentEvent{source, data});
    }

    void VenomBus::startReactive(rxcpp::composite_subscription& lifetime, const Scheduler& scheduler) {
        
        auto baseTick = std::chrono::milliseconds(static_cast<long>(timeCubeBaseline.baseTickMs));

        vent_bus.get_observable()
            .group_by([](const VentEvent& e) { return e.source; })
            // FONTOS: Itt NEM adunk át lifetime-ot, és explicit típust használunk!
            .subscribe([this, &scheduler, baseTick, lifetime](rxcpp::grouped_observable<std::string, VentEvent> grouped_obs) {
                
                grouped_obs
                    .window_with_time_or_count(std::chrono::milliseconds(200), 10)
                    .flat_map([this, &scheduler](rxcpp::observable<VentEvent> window) {
                        
                        return window.reduce(
                            std::vector<VentEvent>(),
                            [](std::vector<VentEvent> acc, VentEvent v) {
                                acc.push_back(v);
                                return acc;
                            })
                        .map([this, &scheduler](std::vector<VentEvent> batch) {
                            if (batch.empty()) return 0;

                            // Metabolizmus alapú dinamikus küszöb [cite: 21]
                            auto meta = telemetry.get_metabolism();
                            double dynamicThreshold = 6.8 * (1.0 / (meta.loadFactor + 0.1));

                            for (const auto& event : batch) {
                                auto profile = telemetry.current_profile.load();
                                auto detected = StreamProbe::detectZeroTrust(event.payload, profile);

                                double entropy = StreamProbe::calculateEntropy(event.payload);
                                bool isSuspicious = (entropy > dynamicThreshold);

                                bool shouldAbsorb = (detected == DataType::BINARY || isSuspicious);
                                auto target = shouldAbsorb ? scheduler.getNullScheduler() : scheduler.getCortexScheduler();

                                rxcpp::observable<>::just(event)
                                    .observe_on(rxcpp::observe_on_one_worker(target))
                                    .subscribe([this, shouldAbsorb](VentEvent e) {
                                        if (shouldAbsorb) {
                                            NullScheduler::absorb(e);
                                            telemetry.null_routed_events++;
                                        } else {
                                            telemetry.accepted_events++;
                                        }
                                        telemetry.queue_depth--;
                                    });
                            }
                            return 0;
                        });
                    })
                    // A belső láncot ráfűzzük a fő élettartamra
                    .subscribe(lifetime, [](auto){});
            });
            
        std::cout << "[VenomBus] Adaptív szakaszos pipeline aktív (Type-Safe Fix)." << std::endl;
    }

    TelemetrySnapshot VenomBus::getTelemetrySnapshot() const {
        return telemetry.snapshot();
    }

} // namespace Venom::Core
