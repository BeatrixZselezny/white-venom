#ifndef SCHEDULER_HPP
#define SCHEDULER_HPP

#include <thread>
#include <atomic>
#include <memory>
#include "rxcpp/rx.hpp"

namespace Venom::Core {

    class VenomBus;
    class BpfLoader;    
    class VisualMemory; 

    class Scheduler {
    private:
        std::atomic<bool> running{false};
        rxcpp::composite_subscription lifetime;

        rxcpp::schedulers::scheduler vent_scheduler;    
        rxcpp::schedulers::scheduler cortex_scheduler;  
        rxcpp::schedulers::scheduler null_scheduler;

    public:
        Scheduler();
        ~Scheduler();

        // A hídhoz szükséges paraméterek: busz, loader és a memória példány
        void start(VenomBus& bus, BpfLoader& loader, VisualMemory& vmem);
        void stop();

        rxcpp::schedulers::scheduler getVentScheduler() const { return vent_scheduler; }
        rxcpp::schedulers::scheduler getCortexScheduler() const { return cortex_scheduler; }
        rxcpp::schedulers::scheduler getNullScheduler() const { return null_scheduler; }
    };
}

#endif
