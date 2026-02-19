#include "core/ebpf/BpfLoader.hpp"
#include <iostream>
#include <net/if.h>
#include <linux/if_link.h>
#include <bpf/libbpf.h>
#include <bpf/bpf.h>
#include <unistd.h>
#include <arpa/inet.h>

namespace Venom::Core {

BpfLoader::BpfLoader() : interfaceName("wlo1"), ifIndex(-1), attached(false), obj_ptr(nullptr) {}
BpfLoader::~BpfLoader() { detach(); }

int BpfLoader::findInterfaceIndex(const std::string& name) {
    return if_nametoindex(name.c_str());
}

bool BpfLoader::deploy(const std::string& objPath, const std::string& iface) {
    interfaceName = iface;
    ifIndex = findInterfaceIndex(interfaceName);
    if (ifIndex == 0) return false;

    obj_ptr = bpf_object__open_file(objPath.c_str(), NULL);
    if (!obj_ptr) return false;

    if (bpf_object__load(obj_ptr)) {
        bpf_object__close(obj_ptr);
        obj_ptr = nullptr;
        return false;
    }

    struct bpf_program *prog = bpf_object__find_program_by_name(obj_ptr, "venom_router_guard");
    int prog_fd = bpf_program__fd(prog);

    if (bpf_xdp_attach(ifIndex, prog_fd, 0, NULL) < 0) {
        bpf_object__close(obj_ptr);
        obj_ptr = nullptr;
        return false;
    }

    attached = true;
    return true;
}

// A Dashboard adatforrása a kernelből
BpfStats BpfLoader::getStats() {
    BpfStats stats = {0, 0};
    if (!attached || !obj_ptr) return stats;

    int map_fd = bpf_object__find_map_fd_by_name(obj_ptr, "stats_map");
    if (map_fd >= 0) {
        uint32_t key_total = 0;
        uint32_t key_dropped = 1;
        bpf_map_lookup_elem(map_fd, &key_total, &stats.total_packets);
        bpf_map_lookup_elem(map_fd, &key_dropped, &stats.dropped_packets);
    }
    return stats;
}

bool BpfLoader::blockIP(const std::string& ip_str) {
    if (!attached || !obj_ptr) return false;
    uint32_t ip;
    if (inet_pton(AF_INET, ip_str.c_str(), &ip) != 1) return false;

    int map_fd = bpf_object__find_map_fd_by_name(obj_ptr, "blacklist_map");
    if (map_fd < 0) return false;

    uint8_t value = 1;
    return bpf_map_update_elem(map_fd, &ip, &value, BPF_ANY) == 0;
}

void BpfLoader::detach() {
    if (attached && obj_ptr) {
        bpf_xdp_detach(ifIndex, 0, NULL);
        bpf_object__close(obj_ptr);
        obj_ptr = nullptr;
        attached = false;
    }
}

} // namespace Venom::Core
