// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Engine v2.2-stable (eBPF Hardened)

#include <iostream>
#include <string>
#include <csignal>
#include <atomic>
#include <thread>
#include <chrono>
#include <iomanip>

#include "core/VenomBus.hpp"
#include "core/Scheduler.hpp"
#include "core/SocketProbe.hpp"
#include "core/ebpf/BpfLoader.hpp"
#include "modules/InitSecurityModule.hpp"
#include "modules/FilesystemModule.hpp"

std::atomic<bool> keepRunning{true};
rxcpp::composite_subscription engine_lifetime;

void signalHandler(int signum) {
    std::cout << "\n[Signal] Megszakítás (" << signum << ")..." << std::endl;
    keepRunning = false;
    if (engine_lifetime.is_subscribed()) engine_lifetime.unsubscribe();
}

int main(int argc, char* argv[]) {
    bool serviceMode = false;
    for (int i = 1; i < argc; ++i) {
        if (std::string(argv[i]) == "--service") serviceMode = true;
    }

    std::signal(SIGINT, signalHandler);
    std::signal(SIGTERM, signalHandler);

    // --- Core Inicializáció ---
    Venom::Core::Scheduler scheduler;
    Venom::Core::VenomBus bus;
    
    // eBPF Vezérlő példányosítása
    Venom::Core::BpfLoader bpfLoader;

    // --- Modulok ---
    Venom::Modules::FilesystemModule fsModule(bus);
    Venom::Core::SocketProbe socketProbe(bus, 8888, Venom::Core::LogLevel::SECURITY_ONLY);

    try {
        // 1. Fázis: Alapvető biztonsági politikák
        {
            Venom::Modules::InitSecurityModule initMod;
            initMod.execute();
        }

        // 2. Fázis: eBPF Pajzs betöltése a wlo1 kártyára
        std::cout << "[Kernel] Deploying eBPF Shield to wlo1..." << std::endl;
        if (!bpfLoader.deploy("obj/venom_shield.bpf.o", "wlo1")) {
            std::cerr << "[WARNING] eBPF Shield deployment failed! Running in user-space mode only." << std::endl;
        } else {
            std::cout << "[Kernel] eBPF Shield is ACTIVE and filtering on wlo1." << std::endl;
        }

        // 3. Fázis: Reaktív motor indítása
        scheduler.start(bus);
        bus.startReactive(engine_lifetime, scheduler);

        // 4. Fázis: Statikus audit
        fsModule.performStaticAudit();

        if (serviceMode) {
            std::cout << "[Mode] Service Mode active. Monitoring wlo1 & Filesystem..." << std::endl;
            fsModule.startMonitoring();
            socketProbe.start();

            while (keepRunning && engine_lifetime.is_subscribed()) {
                std::this_thread::sleep_for(std::chrono::milliseconds(250));
                
                auto snap = bus.getTelemetrySnapshot();
                
                // Reaktív státusz kijelzés
                std::cout << "\r[Status] Q: " << std::setw(3) << snap.queue_current 
                          << " | OK: " << snap.accepted 
                          << " | WC: " << snap.null_routed 
                          << " | Load: " << std::fixed << std::setprecision(2) << snap.current_system_load 
                          << " | eBPF: " << (bpfLoader.isActive() ? "ON" : "OFF")
                          << std::flush;
            }

            socketProbe.stop();
            fsModule.stopMonitoring();
            bpfLoader.detach(); // Leállításkor lekapcsoljuk a pajzsot
        }

    } catch (const std::exception& e) {
        std::cerr << "\n[CRITICAL] Engine hiba: " << e.what() << std::endl;
        engine_lifetime.unsubscribe();
        bpfLoader.detach();
    }

    std::this_thread::sleep_for(std::chrono::milliseconds(200));
    scheduler.stop();
    std::cout << "\n[Shutdown] White-Venom Engine gracefully stopped." << std::endl;

    return 0;
}
