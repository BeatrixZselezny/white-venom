// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#include "Scheduler.hpp"
#include "VenomBus.hpp"
#include <chrono>

namespace Venom::Core {

    void Scheduler::start(VenomBus& bus) {
        running = true;
        
        while (running) {
            // A busz összes regisztrált moduljának futtatása
            bus.runAll();
            
            // Várakozás a következő ciklusig
            std::this_thread::sleep_for(std::chrono::seconds(intervalSeconds));
        }
    }

    void Scheduler::stop() {
        running = false;
    }
}
