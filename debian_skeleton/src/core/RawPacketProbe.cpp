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
        // ... szimulált betöltés ...
        return true;
    }

    void RawPacketProbe::allowRouter(const std::string& mac_addr) {
        // Itt frissítjük a BPF Map-et (a kernel tábláját)
        // A te BSD-s tapasztalatoddal ez olyan, mint egy 'pfctl -t allowed_ips -T add ...'
        std::cout << "[RawPacketProbe] Whitelisting Router MAC: " << mac_addr << std::endl;
    }

    void RawPacketProbe::start() {
        if (!load_ebpf_program()) return;
        running = true;
        worker = std::thread(&RawPacketProbe::capture_loop, this);
    }
    
    // ... stop() és capture_loop() implementáció ...
}#include "core/RawPacketProbe.hpp"
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
                                            // ... szimulált betöltés ...
                                                    return true;
                                                        }

                                                            void RawPacketProbe::allowRouter(const std::string& mac_addr) {
                                                                        // Itt frissítjük a BPF Map-et (a kernel tábláját)
                                                                                // A te BSD-s tapasztalatoddal ez olyan, mint egy 'pfctl -t allowed_ips -T add ...'
                                                                                        std::cout << "[RawPacketProbe] Whitelisting Router MAC: " << mac_addr << std::endl;
                                                                                            }

                                                                                                void RawPacketProbe::start() {
                                                                                                            if (!load_ebpf_program()) return;
                                                                                                                    running = true;
                                                                                                                            worker = std::thread(&RawPacketProbe::capture_loop, this);
                                                                                                                                }
                                                                                                                                    
                                                                                                                                        // ... stop() és capture_loop() implementáció ...
}
