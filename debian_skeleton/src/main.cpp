// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework
// Hardened bootstrap entry point (Refactored for Dual-Bus Arch)

#include <iostream>
#include <string>
#include <memory>
#include <csignal>
#include <atomic>
#include <thread>

// Core
#include "core/VenomBus.hpp"
#include "core/Scheduler.hpp"

// Modules
#include "modules/InitSecurityModule.hpp"
#include "modules/FilesystemModule.hpp" // Visszakapcsolva!

// EZEKET MÉG PORTOLNUNK KELL, MOST NE ZAVARJANAK BE:
// #include "VenomInitializer.hpp"       <-- Ez marad kommentben
// #include "utils/HardeningUtils.hpp"   <-- Ez is marad kommentben


// Globális flag a leállításhoz
std::atomic<bool> keepRunning{true};

void signalHandler(int) {
    std::cout << "\n[Signal] Leállítási kérelem..." << std::endl;
    keepRunning = false;
}

int main(int argc, char* argv[]) {
    // ---- Argument parsing -------------------------------------------------
    bool serviceMode = false;
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--service") {
            serviceMode = true;
        }
    }

    std::signal(SIGINT, signalHandler);

    // ---- Infrastructure Initialization (Dual-Bus) -------------------------
    Venom::Core::Scheduler scheduler;
    Venom::Core::VenomBus bus;
    rxcpp::composite_subscription lifetime;

    std::cout << "[Init] White Venom Engine v2.0 (Dual-Bus Reactive)" << std::endl;

    // ---- Module Instantiation ---------------------------------------------
    // Injektáljuk a Bus-t a "Szemeknek"
    Venom::Modules::FilesystemModule fsModule(bus);

    // ---- Ring 0.5: Bootstrap ----------------------------------------------
    {
        Venom::Modules::InitSecurityModule initMod;
        initMod.execute();
    }

    // ---- Execution Phase --------------------------------------------------
    try {
        scheduler.start(bus);
        bus.startReactive(lifetime, scheduler);

        // Kezdeti audit (statikus szkennelés)
        fsModule.performStaticAudit();

        if (serviceMode) {
            // Szemek kinyitása (Inotify thread indítása)
            std::cout << "[Mode] Service Mode Started. Opening eyes (FS Monitor)..." << std::endl;
            fsModule.startMonitoring();
            
            while (keepRunning) {
                std::this_thread::sleep_for(std::chrono::seconds(1));
                
                auto snap = bus.getTelemetrySnapshot();
                std::cout << "\r[Status] Q: " << snap.queue_current 
                          << " | Events: " << snap.total 
                          << " | Profile: " << (snap.current_profile == SecurityProfile::NORMAL ? "NORMAL" : "HIGH")
                          << std::flush;
            }
            
            // Leállításkor becsukjuk a szemet is
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
