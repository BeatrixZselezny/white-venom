#include "core/ebpf/BpfLoader.hpp"
#include <iostream>
#include <bpf/libbpf.h>
#include <bpf/bpf.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <net/if.h>
#include <cstdio>

namespace Venom::Core {
    BpfLoader::BpfLoader() : obj(nullptr), link(nullptr), attached(false) {}
    BpfLoader::~BpfLoader() { detach(); }

    bool BpfLoader::deploy(const std::string& objPath, const std::string& iface) {
        if (attached) return false;
        obj = bpf_object__open(objPath.c_str());
        if (!obj) return false;
        if (bpf_object__load(obj)) { bpf_object__close(obj); obj = nullptr; return false; }

        int ifindex = if_nametoindex(iface.c_str());
        if (ifindex == 0) return false;

        // A SEC("xdp") alatti függvény neve a .c fájlban!
        struct bpf_program* prog = bpf_object__find_program_by_name(obj, "venom_router_guard");
        if (!prog) return false;

        link = bpf_program__attach_xdp(prog, ifindex);
        if (!link) return false;

        attached = true;
        return true;
    }

    int BpfLoader::get_map_fd(const std::string& map_name) {
        return (obj) ? bpf_object__find_map_fd_by_name(obj, map_name.c_str()) : -1;
    }

    bool BpfLoader::setRouterMAC(const std::string& mac_str) {
        int fd = get_map_fd("router_identity_map");
        if (fd < 0) return false;

        router_identity ident = {};
        ident.trust_level = 1;

        int values[6];
        if (std::sscanf(mac_str.c_str(), "%x:%x:%x:%x:%x:%x", 
            &values[0], &values[1], &values[2], &values[3], &values[4], &values[5]) != 6) {
            return false;
        }

        for (int i = 0; i < 6; ++i) ident.mac[i] = (unsigned char)values[i];

        uint32_t key = 0;
        return bpf_map_update_elem(fd, &key, &ident, BPF_ANY) == 0;
    }

    bool BpfLoader::blockIP(const std::string& ip_str) {
        int fd = get_map_fd("blacklist_map");
        if (fd < 0) return false;
        uint32_t ip_addr;
        if (inet_pton(AF_INET, ip_str.c_str(), &ip_addr) != 1) return false;
        uint8_t value = 1;
        return bpf_map_update_elem(fd, &ip_addr, &value, BPF_ANY) == 0;
    }

    BpfStats BpfLoader::getStats() {
        BpfStats stats{0};
        int fd = get_map_fd("stats_map");
        if (fd < 0) return stats;

        uint32_t key = 0; // STAT_DROPPED index
        uint64_t val = 0;
        if (bpf_map_lookup_elem(fd, &key, &val) == 0) {
            stats.dropped_packets = val;
        }
        return stats;
    }

    void BpfLoader::detach() {
        if (link) { bpf_link__destroy(link); link = nullptr; }
        if (obj) { bpf_object__close(obj); obj = nullptr; }
        attached = false;
    }
}
