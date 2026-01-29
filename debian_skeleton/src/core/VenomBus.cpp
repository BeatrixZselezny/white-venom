// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#include "core/VenomBus.hpp"
#include "core/Scheduler.hpp"
#include <iostream>

namespace Venom::Core {

    VenomBus::VenomBus() {
        // Inicializáljuk a telemetriát
        telemetry.reset_window();
    }

    /**
     * @brief A külvilág (pl. inotify) ezen keresztül tolja be az adatot.
     * Ez Thread-Safe, bármelyik szálról hívható.
     */
    void VenomBus::pushEvent(const std::string& source, const std::string& data) {
        // Telemetria növelése (Atomic, szóval biztonságos)
        telemetry.total_events++;
        telemetry.queue_depth++;

        // Bedobjuk az eseményt a "Vent" (szellőző) buszba
        // Ez még nem dolgozza fel, csak beleteszi a csőbe.
        vent_bus.get_subscriber().on_next(VentEvent{source, data});
    }

    /**
     * @brief Itt történik a csoda: összekötjük a két buszt a Schedulerrel.
     */
    void VenomBus::startReactive(rxcpp::composite_subscription& lifetime, const Scheduler& scheduler) {
        
        // --- THE PIPELINE ---
        
        vent_bus.get_observable()
            // 1. Lépés: Átadás a Vent Schedulernek (Worker Thread Pool)
            .observe_on(rxcpp::observe_on_one_worker(scheduler.getVentScheduler()))
            
            // JAVÍTVA: /*e*/ kommenttel, hogy ne sírjon a fordító
            .tap([this](const VentEvent& /*e*/) {
                // Debug log (opcionális)
                // std::cout << "[Vent] Bejövő adat: " << e.source << std::endl;
            })

            // 2. Lépés: Stream Probe & Routing
            .map([this](VentEvent e) -> CortexCommand {
                return CortexCommand{e.source, "ANALYZE_REQUEST"};
            })
            
            // 3. Lépés: Time-Cube Filter (Szűrés)
            // JAVÍTVA: /*cmd*/ kommenttel
            .filter([this](const CortexCommand& /*cmd*/) {
                // Time-Cube logika helye
                return true;
            })

            // 4. Lépés: Váltás a Cortex Schedulerre (Dedikált vezérlő szál)
            .observe_on(rxcpp::observe_on_one_worker(scheduler.getCortexScheduler()))

            // 5. Lépés: Végrehajtás (Subscription)
            .subscribe(
                lifetime,
                
                // OnNext (Siker) - JAVÍTVA: /*cmd*/
                [this](CortexCommand /*cmd*/) {
                    telemetry.accepted_events++;
                    telemetry.queue_depth--;
                },
                
                // OnError (Hiba) - JAVÍTVA: /*ep*/
                [](std::exception_ptr /*ep*/) {
                    std::cerr << "[VenomBus] Hiba a pipeline-ban!" << std::endl;
                },

                // OnCompleted (Vége)
                []() {
                    std::cout << "[VenomBus] Pipeline lezárult." << std::endl;
                }
            );
            
        std::cout << "[VenomBus] Reaktív pipeline felépítve: Vent -> Cortex" << std::endl;
    }

    TelemetrySnapshot VenomBus::getTelemetrySnapshot() const {
        return telemetry.snapshot();
    }

} // namespace Venom::Core
