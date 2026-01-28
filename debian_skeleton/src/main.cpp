// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework
//
// Hardened bootstrap entry point (Refactored for Dual-Bus Arch)

#include <iostream>
#include <string>
#include <memory>
#include <csignal>
#include <atomic>
#include <thread> // Kell a sleephez

// Core
#include "core/VenomBus.hpp"
#include "core/Scheduler.hpp"

// Modules
#include "modules/InitSecurityModule.hpp"

// EZEKET MÉG PORTOLNUNK KELL, MOST NE ZAVARJANAK BE:
// #include "VenomInitializer.hpp"
// #include "modules/FilesystemModule.hpp"
// #include "utils/HardeningUtils.hpp"

// Globális flag a leállításhoz
std::atomic<bool> keepRunning{true};

void signalHandler(int) {
    std::cout << "\n[Signal] Leállítási kérelem..." << std::endl;
    keepRunning = false;
}

int main(int argc, char* argv[]) {
    // ---- Argument parsing -------------------------------------------------
    bool serviceMode = false;
    bool dryRun = false;

    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--dry-run") {
            dryRun = true; // Később a Configba kell menteni
            std::cout << "[INFO] Dry-Run mode active." << std::endl;
        }
        else if (arg == "--service") {
            serviceMode = true;
        }
        else {
            std::cerr << "[ERROR] Unknown argument: " << arg << std::endl;
            return 1;
        }
    }

    // ---- Signal Handling --------------------------------------------------
    std::signal(SIGINT, signalHandler);

    // ---- Infrastructure Initialization (Dual-Bus) -------------------------
    // Stack allocation a biztonság és sebesség érdekében (Heap helyett)
    Venom::Core::Scheduler scheduler;
    Venom::Core::VenomBus bus;
    rxcpp::composite_subscription lifetime;

    std::cout << "[Init] White Venom Engine v2.0 (Dual-Bus Reactive)" << std::endl;

    // ---- Ring 0.5: Bootstrap ----------------------------------------------
    // Az InitSecurityModule-t most már direktben hívjuk, mert nem "Bus Module"
    {
        Venom::Modules::InitSecurityModule initMod;
        initMod.execute();
    }

    // ---- Execution Phase --------------------------------------------------
    try {
        // 1. Motorok indítása
        scheduler.start(bus);

        // 2. Csövek összekötése (Reactive Pipeline)
        bus.startReactive(lifetime, scheduler);

        // 3. Service Loop
        if (serviceMode) {
            std::cout << "[Mode] Service Mode Started. Listening on Vent Bus..." << std::endl;
            
            // Teszt események generálása, hogy lássuk, működik-e
            bus.pushEvent("SYSTEM", "Service Started");
            
            while (keepRunning) {
                std::this_thread::sleep_for(std::chrono::seconds(1));
                
                // Telemetria kiírása (Dashboard)
                auto snap = bus.getTelemetrySnapshot();
                std::cout << "\r[Status] Q: " << snap.queue_current 
                          << " | Events: " << snap.total 
                          << " | Profile: " << (snap.current_profile == SecurityProfile::NORMAL ? "NORMAL" : "HIGH")
                          << std::flush;
                          
                // Heartbeat a busznak
                bus.pushEvent("HEARTBEAT", "Tick");
            }
        } else {
            // One-shot mode
            std::cout << "[Mode] One-Shot Execution." << std::endl;
            // Itt majd lefuttathatjuk a hardening taskokat és kilépünk
            bus.pushEvent("ONESHOT", "Task Complete");
            std::this_thread::sleep_for(std::chrono::milliseconds(500)); // Hagyunk időt a feldolgozásra
        }

    } catch (const std::exception& e) {
        std::cerr << "[CRITICAL] Exception: " << e.what() << std::endl;
        return 1;
    }

    // ---- Shutdown ---------------------------------------------------------
    std::cout << "\n[Shutdown] Cleaning up..." << std::endl;
    lifetime.unsubscribe();
    scheduler.stop();
    
    return 0;
}
