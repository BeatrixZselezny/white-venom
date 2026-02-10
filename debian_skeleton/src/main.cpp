// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#include <iostream>
#include <string>
#include <memory>
#include <csignal>
#include <atomic>
#include <thread>

#include "core/VenomBus.hpp"
#include "core/Scheduler.hpp"
#include "modules/InitSecurityModule.hpp"
#include "modules/FilesystemModule.hpp"

std::atomic<bool> keepRunning{true};

void signalHandler(int) {
    std::cout << "\n[Signal] Leállítási kérelem..." << std::endl;
    keepRunning = false;
}

int main(int argc, char* argv[]) {
    bool serviceMode = false;
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--service") {
            serviceMode = true;
        }
    }

    std::signal(SIGINT, signalHandler);

    Venom::Core::Scheduler scheduler;
    Venom::Core::VenomBus bus;
    rxcpp::composite_subscription lifetime;

    std::cout << "[Init] White Venom Engine v2.0 (Dual-Bus Reactive)" << std::endl;

    Venom::Modules::FilesystemModule fsModule(bus);

    {
        Venom::Modules::InitSecurityModule initMod;
        initMod.execute();
    }

    try {
        scheduler.start(bus);
        bus.startReactive(lifetime, scheduler);
        fsModule.performStaticAudit();

        if (serviceMode) {
            std::cout << "[Mode] Service Mode Started. Opening eyes (FS Monitor)..." << std::endl;
            fsModule.startMonitoring();
            
            while (keepRunning) {
                std::this_thread::sleep_for(std::chrono::seconds(1));
                
                auto snap = bus.getTelemetrySnapshot();
                // A te struktúrád szerinti mezőnevek: total, accepted
                std::cout << "\r[Status] Q: " << snap.queue_current 
                          << " | Total: " << snap.total 
                          << " | OK: " << snap.accepted 
                          << " | Profile: " << (snap.current_profile == SecurityProfile::NORMAL ? "NORMAL" : "HIGH")
                          << std::flush;
            }
            
            fsModule.stopMonitoring();

        } else {
            std::cout << "[Mode] One-Shot Execution (Audit only)." << std::endl;
            bus.pushEvent("ONESHOT", "Audit Complete");
            std::this_thread::sleep_for(std::chrono::milliseconds(500));
        }

    } catch (const std::exception& e) {
        std::cerr << "[CRITICAL] Exception: " << e.what() << std::endl;
        return 1;
    }

    std::cout << "\n[Shutdown] Cleaning up..." << std::endl;
    lifetime.unsubscribe();
    scheduler.stop();
    
    return 0;
}
