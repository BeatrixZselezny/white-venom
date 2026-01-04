/*
 * End User License Agreement (EULA) - White-Venom (VW)
 * Verzió: 1.0 | Dátum: 2026.01.03 | Szerző: white-venom
 *
 * A Szoftver kizárólag SZEMÉLYES, OKTATÁSI vagy KUTATÁSI célokra használható.
 * Kereskedelmi értékesítése, átcsomagolása (repackaging) vagy szolgáltatásként 
 * való nyújtása (SaaS) a Szerző írásos engedélye nélkül szigorúan TILOS.
 * A Szoftver logikája és egyedi megoldásai szerzői jogi védelem alatt állnak.
 * A Szoftver "ahogy van" állapotban kerül átadásra, felelősséget a használatért
 * a Szerző nem vállal.
 */

#include <iostream>
#include <string>
#include <vector>
#include <memory>

// Core összetevők
#include "core/VenomBus.hpp"
#include "core/Scheduler.hpp"
#include "core/SafeExecutor.hpp"

// Modulok
#include "modules/SysctlModule.hpp"

// Utils és Init
#include "VenomInitializer.hpp"
#include "utils/HardeningUtils.hpp"
#include "utils/ConfigTemplates.hpp"

/**
 * White Venom Hardened Engine - Main Entry Point
 * Platform: Debian (Zero Trust Process Integrity)
 */

int main(int argc, char* argv[]) {
    bool serviceMode = false;

    // Argumentumok feldolgozása
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--dry-run") {
            VenomUtils::DRY_RUN = true;
        } else if (arg == "--service") {
            serviceMode = true;
        }
    }

    // T0: Környezet sterilizáció és root check
    Venom::Init::purgeUnsafeEnvironment();
    
    if (!Venom::Init::isRoot()) {
        std::cerr << "[ERROR] Root privileges required for Debian hardening." << std::endl;
        return 1;
    }

    // A központi Busz inicializálása
    auto bus = std::make_shared<Venom::Core::VenomBus>();

    // Modulok regisztrálása (Alacsony szintű natív implementáció)
    bus->registerModule(std::make_shared<Venom::Modules::SysctlModule>());

    // Rendszer-előkészítés és integritás
    VenomUtils::checkLDSanity();
    Venom::Init::createSecureSkeleton();
    
    // Debian konfigurációs bootstrap
    VenomUtils::writeProtectedFile("/etc/make.conf", VenomTemplates::MAKE_CONF_CONTENT);

    // Canary integritás-figyelő aktiválása
    Venom::Init::deployCanary();

    // Futtatási ciklus indítása
    if (serviceMode) {
        // Ring 3: Biztonsági ütemező (5 perces ciklus)
        Venom::Core::Scheduler scheduler(300);
        scheduler.start(*bus);
    } else {
        // Ring 1: Egyszeri bootstrap futtatás
        bus->runAll();
    }

    std::cout << "[SUCCESS] White Venom engine operation completed." << std::endl;
    
    return 0;
}
