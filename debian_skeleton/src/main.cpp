// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Engine v3.0-stable (Dashboard Edition)

#include <iostream>
#include <string>
#include <csignal>
#include <atomic>
#include <thread>
#include <chrono>
#include <iomanip>
#include <vector>
#include <cmath>

#include "core/VenomBus.hpp"
#include "core/Scheduler.hpp"
#include "core/SocketProbe.hpp"
#include "core/ebpf/BpfLoader.hpp"
#include "modules/InitSecurityModule.hpp"
#include "modules/FilesystemModule.hpp"

std::atomic<bool> keepRunning{true};
rxcpp::composite_subscription engine_lifetime;

// Vizuális segédfüggvények (ANSI)
void clearScreen() { std::cout << "\033[2J\033[H"; }
void setGreen() { std::cout << "\033[1;32m"; }
void setRed() { std::cout << "\033[1;31m"; }
void resetColor() { std::cout << "\033[0m"; }

void signalHandler(int signum) {
    (void)signum; // Elnémítjuk a warningot: tudjuk, hogy itt van, de nem használjuk
    keepRunning = false;
    if (engine_lifetime.is_subscribed()) engine_lifetime.unsubscribe();
}

// A rate paramétert is elnémítjuk, amíg nem használjuk a szívverés ütemezéséhez
std::string getHeartbeat(int tick, int rate) {
    (void)rate; 
    std::string frame = "---";
    if (tick % 4 == 0) frame = "-^-";
    else if (tick % 4 == 1) frame = "/ \\";
    return frame;
}

int main(int argc, char* argv[]) {
    bool serviceMode = false;
    for (int i = 1; i < argc; ++i) {
        if (std::string(argv[i]) == "--service") serviceMode = true;
    }

    std::signal(SIGINT, signalHandler);
    std::signal(SIGTERM, signalHandler);

    Venom::Core::Scheduler scheduler;
    Venom::Core::VenomBus bus;
    Venom::Core::BpfLoader bpfLoader;
    Venom::Modules::FilesystemModule fsModule(bus);
    Venom::Core::SocketProbe socketProbe(bus, 8888, Venom::Core::LogLevel::SECURITY_ONLY);

    try {
        {
            Venom::Modules::InitSecurityModule initMod;
            initMod.execute();
        }

        if (!bpfLoader.deploy("obj/venom_shield.bpf.o", "wlo1")) {
            // Deploy hiba kezelve
        }

        scheduler.start(bus);
        bus.startReactive(engine_lifetime, scheduler);
        fsModule.performStaticAudit();

        if (serviceMode) {
            fsModule.startMonitoring();
            socketProbe.start();

            int frameCounter = 0;
            while (keepRunning && engine_lifetime.is_subscribed()) {
                auto snap = bus.getTelemetrySnapshot();
                auto bpfStats = bpfLoader.getStats();

                clearScreen();
                setGreen();
                std::cout << "#########################################################" << std::endl;
                std::cout << "#  WHITE VENOM v3.0 - CLI Dashboard          [ RUNNING ] #" << std::endl;
                std::cout << "#########################################################" << std::endl;
                
                std::cout << "\n TOTAL FLUSHED BITS (Kernel Drop): ";
                setRed();
                std::cout << bpfStats.dropped_packets << " PKTS" << std::endl;
                setGreen();

                std::cout << "\n SCHEDULER DOMAINS:" << std::endl;
                std::cout << " [ BUS Q: " << std::setw(3) << snap.queue_current << " ]  " 
                          << " [ LOAD: " << std::fixed << std::setprecision(2) << snap.current_system_load << " ]" << std::endl;

                std::cout << "\n CORE TELEMETRY:" << std::endl;
                std::cout << " > Accepted: " << snap.accepted << std::endl;
                std::cout << " > Filtered: " << snap.null_routed << std::endl;
                
                // Heartbeat animáció
                std::cout << "\n HEARTBEAT: [ " << getHeartbeat(frameCounter++, 0) << " ]" << std::endl;
                
                // Egyszerű "grafikon" imitáció
                std::cout << "\n TRAFFIC PROFILE:" << std::endl;
                int barLen = (int)(snap.current_system_load * 20) % 40;
                std::cout << " [";
                for(int i=0; i<40; ++i) std::cout << (i < barLen ? "|" : ".");
                std::cout << "]" << std::endl;

                std::cout << "\n---------------------------------------------------------" << std::endl;
                std::cout << " eBPF Shield: " << (bpfLoader.isActive() ? "[ ACTIVE ON WLO1 ]" : "[ OFF ]") << std::endl;
                resetColor();

                std::this_thread::sleep_for(std::chrono::milliseconds(200));
            }

            socketProbe.stop();
            fsModule.stopMonitoring();
            bpfLoader.detach();
        }
    } catch (const std::exception& e) {
        std::cerr << "\n[CRITICAL] Engine hiba: " << e.what() << std::endl;
        bpfLoader.detach();
    }

    scheduler.stop();
    return 0;
}
