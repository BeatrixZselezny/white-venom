// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#ifndef BPFLOADER_HPP
#define BPFLOADER_HPP

#include <string>
#include <atomic>
#include <vector>
#include <cstdint>

// Forward declaration a libbpf-nek
struct bpf_object;
struct bpf_link;

namespace Venom::Core {

    struct BpfStats {
        uint64_t dropped_packets;
    };

    // A venom_ebpf_common.h-val szinkronizált struktúra
    struct router_identity {
        unsigned char mac[6];
        uint32_t trust_level;
    };

    class BpfLoader {
    private:
        struct bpf_object* obj;
        struct bpf_link* link;
        std::atomic<bool> attached;

    public:
        explicit BpfLoader();
        ~BpfLoader();

        bool deploy(const std::string& objPath, const std::string& iface);
        void detach();
        
        // Injekció-mentes MAC beállítás (SafeExecutor logika)
        bool setRouterMAC(const std::string& mac_str);
        
        bool blockIP(const std::string& ip_str);
        int get_map_fd(const std::string& map_name);
        BpfStats getStats();
        
        bool isActive() const { return attached.load(); }
    };
}

#endif
