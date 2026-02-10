// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#include "core/VenomBus.hpp"
#include "core/Scheduler.hpp"
#include "core/StreamProbe.hpp"
#include "core/NullScheduler.hpp"
#include <iostream>

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
        
        // TimeCube baseTickMs paramétere alapján számoljuk a debounce-ot
        auto debounceTime = std::chrono::milliseconds(static_cast<long>(timeCubeBaseline.baseTickMs));

        // A trükk: Előbb elkészítjük az observable-t, és csak a végén iratkozunk fel
        vent_bus.get_observable()
            .group_by([](const VentEvent& e) { return e.source; })
            .map([this, &scheduler, debounceTime, &lifetime](rxcpp::grouped_observable<std::string, VentEvent> grouped_obs) {
                // Itt a grouped_obs típusa már garantáltan helyes
                return grouped_obs
                    .debounce(debounceTime)
                    .observe_on(rxcpp::observe_on_one_worker(scheduler.getVentScheduler()))
                    .map([this](VentEvent e) {
                        auto profile = telemetry.current_profile.load();
                        auto detected = StreamProbe::detectZeroTrust(e.payload, profile);
                        return std::make_pair(e, detected);
                    })
                    .map([this, &scheduler](std::pair<VentEvent, DataType> result) {
                        auto event = result.first;
                        auto detected = result.second;

                        bool shouldAbsorb = (detected == DataType::BINARY || detected == DataType::UNKNOWN);
                        auto target = shouldAbsorb ? scheduler.getNullScheduler() : scheduler.getCortexScheduler();

                        // Az utolsó láncszem: a tényleges végrehajtás
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
                        return 0; // Dummy return a map-nek
                    });
            })
            .subscribe(lifetime, [](auto) {}); 
            
        std::cout << "[VenomBus] Zero-Trust immun-pipeline aktív (Safe-Type Mode)." << std::endl;
    }

    TelemetrySnapshot VenomBus::getTelemetrySnapshot() const {
        return telemetry.snapshot();
    }

} // namespace Venom::Core
