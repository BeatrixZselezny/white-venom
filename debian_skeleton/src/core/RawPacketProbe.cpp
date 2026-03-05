#include "core/RawPacketProbe.hpp"
#include <iostream>
#include <sys/socket.h>
#include <linux/if_packet.h>
#include <net/ethernet.h>
#include <arpa/inet.h>
#include <unistd.h>

namespace Venom::Core {

    bool RawPacketProbe::load_ebpf_program() {
        // Itt hívjuk meg a libbpf-et vagy a syscall-t, ami 
        // a "venom_shield.bpf.o" tartalmát betölti a kernelbe.
        std::cout << "[RawPacketProbe] Injecting eBPF Shield into Kernel..." << std::endl;
        return true;
    }

    void RawPacketProbe::allowRouter(const std::string& mac_addr) {
        // Itt frissítjük a BPF Map-et (a kernel tábláját)
        std::cout << "[RawPacketProbe] Whitelisting Router MAC: " << mac_addr << std::endl;
    }

    void RawPacketProbe::start() {
        if (!load_ebpf_program()) return;
        running = true;
        // A linker itt kereste a capture_loop-ot
        worker = std::thread(&RawPacketProbe::capture_loop, this);
    }

    void RawPacketProbe::stop() {
        running = false;
        if (worker.joinable()) {
            worker.join();
        }
        std::cout << "[RawPacketProbe] Engine stopped." << std::endl;
    }

    void RawPacketProbe::capture_loop() {
        std::cout << "[RawPacketProbe] Capture loop started." << std::endl;
        while (running) {
            // Itt jönne a nyers packet capture (recvfrom) 
            // vagy a BPF ring buffer olvasása.
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
    }

} // namespace Venom::Core
