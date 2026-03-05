// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework - SocketProbe (Stable Build)

#include "core/SocketProbe.hpp"
#include <iostream>
#include <sys/socket.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/select.h>
#include <cstring>
#include <chrono>
#include <sys/time.h>
#include <netinet/in.h>
#include <thread>

namespace Venom::Core {

    SocketProbe::SocketProbe(VenomBus& vBus, int listenPort, LogLevel level) 
        : bus(vBus), serverFd(-1), port(listenPort), keepRunning(false), currentLogLevel(level) {}

    SocketProbe::~SocketProbe() {
        stop();
    }

    void SocketProbe::start() {
        if (keepRunning) return;

        serverFd = socket(AF_INET, SOCK_STREAM, 0);
        if (serverFd < 0) return;

        int opt = 1;
        setsockopt(serverFd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        struct sockaddr_in address{};
        address.sin_family = AF_INET;
        address.sin_addr.s_addr = INADDR_ANY;
        address.sin_port = htons(port);

        if (bind(serverFd, (struct sockaddr*)&address, sizeof(address)) < 0) {
            close(serverFd);
            serverFd = -1;
            return;
        }

        if (listen(serverFd, 128) < 0) {
            close(serverFd);
            return;
        }

        fcntl(serverFd, F_SETFL, O_NONBLOCK);

        keepRunning = true;
        workerThread = std::thread(&SocketProbe::listenLoop, this);
        
        if (currentLogLevel != LogLevel::SILENT) {
            std::cout << "[SocketProbe] Vadászterület megnyitva a porton: " << port << std::endl;
        }
    }

    void SocketProbe::listenLoop() {
        struct timeval tcpTimeout{1, 0}; 

        while (keepRunning) {
            struct sockaddr_in clientAddr{};
            socklen_t addrLen = sizeof(clientAddr);
            
            int clientFd = accept(serverFd, (struct sockaddr*)&clientAddr, &addrLen);

            if (clientFd < 0) {
                std::this_thread::sleep_for(std::chrono::milliseconds(1));
                continue;
            }

            setsockopt(clientFd, SOL_SOCKET, SO_RCVTIMEO, (const char*)&tcpTimeout, sizeof(tcpTimeout));

            char buffer[2048];
            ssize_t valRead = read(clientFd, buffer, sizeof(buffer));
            
            if (valRead > 0) {
                // Aszinkron beküldés, hogy ne akassza meg az accept() ciklust
                std::string eventData(buffer, valRead);
                std::thread([this, eventData]() {
                    bus.pushEvent("NET_SOCKET_" + std::to_string(port), eventData);
                }).detach();
            }
            
            close(clientFd);
        }
    }

    void SocketProbe::stop() {
        if (!keepRunning) return;
        keepRunning = false;
        if (workerThread.joinable()) {
            workerThread.join();
        }
        if (serverFd >= 0) {
            close(serverFd);
            serverFd = -1;
        }
    }

} // namespace Venom::Core
