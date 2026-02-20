#include "core/ebpf/BpfLoader.hpp"
#include <iostream>
#include <bpf/libbpf.h>
#include <bpf/bpf.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <net/if.h>

namespace Venom::Core {
    BpfLoader::BpfLoader() : obj(nullptr), link(nullptr), attached(false) {}
    BpfLoader::~BpfLoader() { detach(); }

    bool BpfLoader::deploy(const std::string& objPath, const std::string& iface) {
        if (attached) return false;
        obj = bpf_object__open(objPath.c_str());
        if (!obj) return false;
        if (bpf_object__load(obj)) { bpf_object__close(obj); obj = nullptr; return false; }

        int ifindex = if_nametoindex(iface.c_str());
        // FIX: A .c fájlban lévő pontos név kell!
        struct bpf_program* prog = bpf_object__find_program_by_name(obj, "venom_router_guard");
        if (!prog) return false;

        // FIX: A linket el kell tárolni, különben a 6.x kernel azonnal lecsatolja
        link = bpf_program__attach_xdp(prog, ifindex);
        if (!link) return false;

        attached = true;
        return true;
    }

    int BpfLoader::get_map_fd(const std::string& map_name) {
        return (obj) ? bpf_object__find_map_fd_by_name(obj, map_name.c_str()) : -1;
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
        uint32_t key = 1; // Dropped slot
        bpf_map_lookup_elem(fd, &key, &stats.dropped_packets);
        return stats;
    }

    void BpfLoader::detach() {
        if (link) { bpf_link__destroy(link); link = nullptr; }
        if (obj) { bpf_object__close(obj); obj = nullptr; }
        attached = false;
    }
}
