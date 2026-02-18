#ifndef BPF_LOADER_HPP
#define BPF_LOADER_HPP

#include <string>
#include <atomic>
#include <bpf/libbpf.h>

namespace Venom::Core {

    struct BpfStats {
        uint64_t total_packets;
        uint64_t dropped_packets;
    };

    class BpfLoader {
    private:
        std::string interfaceName;
        int ifIndex;
        std::atomic<bool> attached;
        struct bpf_object *obj_ptr;

        int findInterfaceIndex(const std::string& name);

    public:
        explicit BpfLoader();
        ~BpfLoader();

        bool deploy(const std::string& objPath, const std::string& iface);
        void detach();
        bool blockIP(const std::string& ip_str);
        BpfStats getStats(); // A Dashboard adatforrása
        bool isActive() const { return attached.load(); }
    };

} // namespace Venom::Core

#endif
