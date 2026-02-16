// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Engine v2.1-stable (with WC monitoring)

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
    for (int i = 1; i < argc; ++i) if (std::string(argv[i]) == "--service") serviceMode = true;

    std::signal(SIGINT, signalHandler);
    std::signal(SIGTERM, signalHandler);

    Venom::Core::Scheduler scheduler;
    Venom::Core::VenomBus bus;
    Venom::Modules::FilesystemModule fsModule(bus);
    Venom::Core::SocketProbe socketProbe(bus, 8888, Venom::Core::LogLevel::SECURITY_ONLY);

    try {
        { Venom::Modules::InitSecurityModule initMod; initMod.execute(); }
        scheduler.start(bus);
        bus.startReactive(engine_lifetime, scheduler);
        fsModule.performStaticAudit();

        if (serviceMode) {
            std::cout << "[Mode] Service Mode: Monitoring FS & Network..." << std::endl;
            fsModule.startMonitoring();
            socketProbe.start();

            while (keepRunning && engine_lifetime.is_subscribed()) {
                std::this_thread::sleep_for(std::chrono::milliseconds(250));
                auto snap = bus.getTelemetrySnapshot();
                
                // MOST MÁR LÁTSZIK A WC (null_routed) IS!
                std::cout << "\r[Status] Q: " << snap.queue_current 
                          << " | OK: " << snap.accepted 
                          << " | WC: " << snap.null_routed 
                          << " | Load: " << std::fixed << std::setprecision(2) << snap.current_system_load 
                          << " | Profile: " << (snap.current_profile == SecurityProfile::NORMAL ? "NORMAL" : "HIGH")
                          << std::flush;
            }
            socketProbe.stop();
            fsModule.stopMonitoring();
        }
    } catch (const std::exception& e) {
        std::cerr << "\n[CRITICAL] Engine hiba: " << e.what() << std::endl;
        engine_lifetime.unsubscribe();
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(200));
    scheduler.stop();
    std::cout << "[Shutdown] White-Venom leállt. 🐱" << std::endl;
    return 0;
}
