// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework - SocketProbe (Zero-Trust Ingress)

#ifndef VENOM_SOCKET_PROBE_HPP
#define VENOM_SOCKET_PROBE_HPP

#include <string>
#include <atomic>
#include <thread>
#include <netinet/in.h>

#include "core/VenomBus.hpp"
#include "TimeCubeTypes.hpp"

namespace Venom::Core {

    /**
     * @brief Log-szintek a hálózati zaj kezeléséhez.
     */
    enum class LogLevel { SILENT, SECURITY_ONLY, DEBUG };

    /**
     * @brief SocketProbe: Hálózati forgalom elfogása és buszra irányítása RX-szabályozással.
     */
    class SocketProbe {
    private:
        VenomBus& bus;
        int serverFd;
        int port;
        std::atomic<bool> keepRunning;
        std::thread workerThread;
        
        LogLevel currentLogLevel;
        std::atomic<uint64_t> rxDropCounter{0};

        void listenLoop();

    public:
        explicit SocketProbe(VenomBus& vBus, int listenPort = 8888, LogLevel level = LogLevel::SECURITY_ONLY);
        ~SocketProbe();

        void start();
        void stop(); // Clean Shutdown támogatás [cite: 13, 258, 268]

        void setLogLevel(LogLevel level) { currentLogLevel = level; }
    };
}

#endif
