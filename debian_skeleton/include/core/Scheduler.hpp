// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework
// Dual-Bus Scheduler: Manages the Twin-Bus Concurrency Model

#ifndef SCHEDULER_HPP
#define SCHEDULER_HPP

#include <thread>
#include <atomic>
#include <memory>
#include "rxcpp/rx.hpp" // A reaktív motor

namespace Venom::Core {

    class VenomBus; // Forward declaration

    /**
     * @brief A Dual-Venom architektúra ütemezője.
     */
    class Scheduler {
    private:
        // --- State ---
        std::atomic<bool> running{false};
        
        // A fő subscription, ami életben tartja a folyamatokat.
        rxcpp::composite_subscription lifetime;

        // --- RxCpp Schedulers (The Twin Engines) ---
        
        // 1. The Vent (Szellőztető): Párhuzamos worker szálak
        rxcpp::schedulers::scheduler vent_scheduler;
        
        // 2. The Cortex (Agykéreg): Egyetlen, dedikált szál
        rxcpp::schedulers::scheduler cortex_scheduler;

    public:
        // FONTOS: Ez az új, paraméter nélküli konstruktor!
        Scheduler();
        ~Scheduler();

        void start(VenomBus& bus);
        void stop();

        // --- Accessors ---
        rxcpp::schedulers::scheduler getVentScheduler() const { 
            return vent_scheduler; 
        }

        rxcpp::schedulers::scheduler getCortexScheduler() const { 
            return cortex_scheduler; 
        }
    };
}

#endif // SCHEDULER_HPP
