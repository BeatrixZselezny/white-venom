// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

// FONTOS: Helyes útvonalak a mappastruktúrához!
#include "core/Scheduler.hpp"
#include "core/VenomBus.hpp" 
#include <iostream>

namespace Venom::Core {

    // Itt a konstruktor megvalósítása, amihez most már illeszkedni fog a header
    Scheduler::Scheduler() {
        // Inicializáljuk a két "hajtóművet"
        
        // 1. Vent: Worker Thread Pool a nagy forgalomhoz
        vent_scheduler = rxcpp::schedulers::make_event_loop();
        
        // 2. Cortex: Dedikált szál a precíz döntésekhez
        cortex_scheduler = rxcpp::schedulers::make_new_thread();
    }

    Scheduler::~Scheduler() {
        stop();
    }

    void Scheduler::start(VenomBus& bus) {
        if (running) return;
        (void)bus;
        running = true;

        std::cout << "[Scheduler] Dual-Bus Engines Starting..." << std::endl;
        
        // Itt még nincs "while" ciklus, csak az RxCpp indítása
        // bus.startReactive(lifetime, *this); 
        
        std::cout << "[Scheduler] Systems Active. Press Ctrl+C to stop." << std::endl;
    }

    void Scheduler::stop() {
        if (!running) return;
        
        std::cout << "[Scheduler] Stopping subsystems..." << std::endl;
        
        // Most már ismerni fogja a 'lifetime'-ot, mert benne van a headerben
        if (lifetime.is_subscribed()) {
            lifetime.unsubscribe();
        }

        running = false;
    }
}
