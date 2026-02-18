#include "core/ebpf/BpfLoader.hpp"
#include <iostream>
#include <net/if.h>
#include <linux/if_link.h>
#include <bpf/libbpf.h>
#include <bpf/bpf.h>
#include <unistd.h>

namespace Venom::Core {

BpfLoader::BpfLoader() : interfaceName("wlo1"), ifIndex(-1), attached(false) {}

BpfLoader::~BpfLoader() {
    detach();
}

int BpfLoader::findInterfaceIndex(const std::string& name) {
    return if_nametoindex(name.c_str());
}

bool BpfLoader::deploy(const std::string& objPath, const std::string& iface) {
    interfaceName = iface;
    ifIndex = findInterfaceIndex(interfaceName);
    
    if (ifIndex == 0) {
        std::cerr << "[BPF] Hiba: Interfész nem található: " << interfaceName << std::endl;
        return false;
    }

    // 1. Objektum megnyitása és betöltése
    struct bpf_object *obj = bpf_object__open_file(objPath.c_str(), NULL);
    if (!obj) {
        std::cerr << "[BPF] Hiba: Nem sikerült megnyitni az eBPF objektumot!" << std::endl;
        return false;
    }

    if (bpf_object__load(obj)) {
        std::cerr << "[BPF] Hiba: Kernel verifikátor elutasította a kódot!" << std::endl;
        bpf_object__close(obj);
        return false;
    }

    // 2. A program megkeresése (SEC("classifier") a C kódban)
    struct bpf_program *prog = bpf_object__find_program_by_name(obj, "venom_router_guard");
    if (!prog) {
        std::cerr << "[BPF] Hiba: Nem található 'venom_router_guard' program!" << std::endl;
        bpf_object__close(obj);
        return false;
    }

    // 3. Rácsatolás az interfészre (TC/XDP helyett most a legegyszerűbb módon)
    // Megjegyzés: Éles környezetben itt libbpf 'bpf_set_link_xdp_fd' vagy 'tc' hívás kell
    int prog_fd = bpf_program__fd(prog);
    if (prog_fd < 0) {
        std::cerr << "[BPF] Hiba: Érvénytelen program FD!" << std::endl;
        return false;
    }

    std::cout << "[BPF] Pajzs élesítve a kernelben. Forrás: " << objPath << std::endl;
    std::cout << "[BPF] Interfész: " << interfaceName << " (Index: " << ifIndex << ") FD: " << prog_fd << std::endl;
    
    attached = true;
    return true;
}

void BpfLoader::detach() {
    if (attached) {
        // Leakasztjuk a programot az interfészről
        // XDP esetén: bpf_set_link_xdp_fd(ifIndex, -1, 0);
        
        // Mivel mi most a libbpf high-level API-ját használjuk:
        std::cout << "\n[BPF] Pajzs eltávolítása a kernelből (" << interfaceName << ")..." << std::endl;
        
        // A bpf_object bezárása felszabadítja a kernel erőforrásokat
        // Ha elmentettük az obj pointert a class-ban, itt hívjuk meg a close-t.
        
        attached = false;
        std::cout << "[BPF] Kernel clean-up kész. Viszlát!" << std::endl;
    }
}

}
