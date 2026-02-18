#ifndef BPF_LOADER_HPP
#define BPF_LOADER_HPP

#include <string>
#include <atomic>

namespace Venom::Core {

    class BpfLoader {
    private:
        std::string interfaceName;
        int ifIndex;
        std::atomic<bool> attached;

        // Belső segéd: megkeresi az interfész numerikus azonosítóját (pl. wlo1 -> 3)
        int findInterfaceIndex(const std::string& name);

    public:
        explicit BpfLoader();
        ~BpfLoader();

        /**
         * @brief eBPF bájtkód betöltése és rácsatolása a hálózati kártyára.
         * @param objPath A lefordított .o fájl helye (pl. "obj/venom_shield.bpf.o")
         * @param iface Az interfész neve (pl. "wlo1")
         */
        bool deploy(const std::string& objPath, const std::string& iface);

        /**
         * @brief Eltávolítja a szűrőt a kernelből.
         */
        void detach();

        /**
         * @brief Egy MAC címet fehérlistára tesz a kernel-szintű eBPF map-ben.
         */
        bool allowRouterMac(const std::string& mac_str);

        // Lekérdezhető állapot
        bool isActive() const { return attached.load(); }
    };

} // namespace Venom::Core

#endif // BPF_LOADER_HPP
