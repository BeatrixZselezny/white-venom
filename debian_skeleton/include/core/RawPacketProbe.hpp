#pragma once
#include "core/VenomBus.hpp"
#include <atomic>
#include <thread>
#include <string>
#include <vector>

namespace Venom::Core {

    class RawPacketProbe {
    private:
        VenomBus& bus;
        std::atomic<bool> running{false};
        std::thread worker;
        int bpf_obj_fd; // A betöltött eBPF program fájlleírója
        int map_fd;     // A "fehérlista" tábla leírója

        void capture_loop();
        bool load_ebpf_program();

    public:
        explicit RawPacketProbe(VenomBus& vBus);
        ~RawPacketProbe();

        void start();
        void stop();
        
        // Ez az, amit kértél: dinamikusan adhatunk hozzá routert
        void allowRouter(const std::string& mac_addr);
    };
}
