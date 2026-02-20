#include "core/Scheduler.hpp"
#include "core/VenomBus.hpp" 
#include "core/ebpf/BpfLoader.hpp"
#include "core/VisualMemory.hpp"
#include <iostream>
#include <bpf/bpf.h>

namespace Venom::Core {
    Scheduler::Scheduler() {
        vent_scheduler = rxcpp::schedulers::make_event_loop();
        cortex_scheduler = rxcpp::schedulers::make_new_thread();
        null_scheduler = rxcpp::schedulers::make_current_thread();
    }

    Scheduler::~Scheduler() {
        stop();
    }

    void Scheduler::start(VenomBus& bus, BpfLoader& loader, VisualMemory& vmem) {
        if (running) return;
        running = true;

        int fd = loader.get_map_fd("blacklist_map");

        vmem.set_blocking_callback([fd, &bus](uint32_t bad_ip) {
            if (fd >= 0) {
                uint8_t blocked = 1;
                bpf_map_update_elem(fd, &bad_ip, &blocked, BPF_ANY);
            }
            // Két paraméter: source és data a VenomBus.hpp szerint
            bus.pushEvent("CORTEX", "NULL_ROUTE: IP_BLOCKED: " + std::to_string(bad_ip));
        });

        std::cout << "[Scheduler] Bridge Active. Kernel + User-Space sync OK." << std::endl;
    }

    void Scheduler::stop() {
        if (!running) return;
        
        if (lifetime.is_subscribed()) {
            lifetime.unsubscribe();
        }

        running = false;
    }
}
