// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#ifndef SCHEDULER_HPP
#define SCHEDULER_HPP

#include <thread>
#include <atomic>
#include <memory>
#include "rxcpp/rx.hpp"

namespace Venom::Core {

    class VenomBus;

    class Scheduler {
    private:
        std::atomic<bool> running{false};
        rxcpp::composite_subscription lifetime;

        // Három izolált végrehajtási domén
        rxcpp::schedulers::scheduler vent_scheduler;    
        rxcpp::schedulers::scheduler cortex_scheduler;  
        rxcpp::schedulers::scheduler null_scheduler;    // A fordító által hiányolt tag

    public:
        Scheduler();
        ~Scheduler();

        void start(VenomBus& bus);
        void stop();

        rxcpp::schedulers::scheduler getVentScheduler() const { return vent_scheduler; }
        rxcpp::schedulers::scheduler getCortexScheduler() const { return cortex_scheduler; }
        
        // Ez a metódus javítja a 'has no member named getNullScheduler' hibát
        rxcpp::schedulers::scheduler getNullScheduler() const { return null_scheduler; }
    };
}

#endif
