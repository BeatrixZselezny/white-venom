// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework
// Dual-Bus Scheduler Implementation: Vent, Cortex, and Null domains.

#include "core/Scheduler.hpp"
#include "core/VenomBus.hpp" 
#include <iostream>

namespace Venom::Core {

    Scheduler::Scheduler() {
        // 1. Vent: Párhuzamos worker pool az események fogadásához és előszűréséhez.
        vent_scheduler = rxcpp::schedulers::make_event_loop();
        
        // 2. Cortex: Egyetlen, dedikált szál a biztonsági logika futtatásához.
        // Ezzel garantáljuk a determinisztikus sorrendiséget a döntéseknél.
        cortex_scheduler = rxcpp::schedulers::make_new_thread();
        
        // 3. Null: Az elnyelő (sink). Az RxCpp current_thread-et használjuk,
        // ami azonnal végrehajtja (vagyis elnyeli) a feladatot extra erőforrás nélkül.
        null_scheduler = rxcpp::schedulers::make_current_thread();
    }

    Scheduler::~Scheduler() {
        stop();
    }

    void Scheduler::start(VenomBus& bus) {
        if (running) return;
        (void)bus; // A busz reaktív láncát maga a VenomBus indítja el.
        running = true;

        std::cout << "[Scheduler] Dual-Bus Engines (with Null-Sink) Active." << std::endl;
    }

    void Scheduler::stop() {
        if (!running) return;
        
        std::cout << "[Scheduler] Stopping subsystems and clearing subscriptions..." << std::endl;
        
        // Felszabadítjuk a reaktív láncokat, hogy ne maradjanak függő szálak.
        if (lifetime.is_subscribed()) {
            lifetime.unsubscribe();
        }

        running = false;
    }

} // namespace Venom::Core
