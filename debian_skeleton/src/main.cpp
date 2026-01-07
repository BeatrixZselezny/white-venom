// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework
//
// Hardened bootstrap entry point
// Platform: Debian (Zero Trust, user-first, policy-driven)

#include <iostream>
#include <string>
#include <memory>

// Core
#include "core/VenomBus.hpp"
#include "core/Scheduler.hpp"

// Init / bootstrap
#include "VenomInitializer.hpp"

// Modules
#include "modules/InitSecurityModule.hpp"
#include "modules/FilesystemModule.hpp"

// Utils
#include "utils/HardeningUtils.hpp"

int main(int argc, char* argv[]) {
    bool serviceMode = false;

    // ---- Argument parsing (STRICT, NO MAGIC) ------------------------------
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];

        if (arg == "--dry-run") {
            VenomUtils::DRY_RUN = true;
        }
        else if (arg == "--service") {
            serviceMode = true;
        }
        else {
            std::cerr << "[ERROR] Unknown argument: " << arg << std::endl;
            return 1;
        }
    }

    // ---- T0: Environment sanitization -------------------------------------
    // No trust in inherited environment
    Venom::Init::purgeUnsafeEnvironment();

    // ---- Bus initialization (NEVER NULL) ----------------------------------
    auto bus = std::make_shared<Venom::Core::VenomBus>();

    // ---- Ring 0.5: Security & policy bootstrap -----------------------------
    // Loads ExecPolicies, input contracts, decision logic
    bus->registerModule(
        std::make_shared<Venom::Modules::InitSecurityModule>()
    );

    // ---- Ring 1: User-space safe preparation ------------------------------
    // These modules must NOT assume root unless explicitly escalated later
    bus->registerModule(
        std::make_shared<Venom::Modules::FilesystemModule>()
    );

    // ---- Integrity checks (user-space safe) --------------------------------
    VenomUtils::checkLDSanity();

    // ---- Privilege boundary ------------------------------------------------
    // Root is REQUIRED only if system mutation is requested
    if (!Venom::Init::isRoot()) {
        std::cerr
            << "[ERROR] Root privileges required for system hardening phase.\n"
            << "        Run with elevated privileges or use --dry-run."
            << std::endl;
        return 1;
    }

    // ---- Secure system skeleton -------------------------------------------
    Venom::Init::createSecureSkeleton();
    Venom::Init::deployCanary();

    // ---- Execution phase ---------------------------------------------------
    if (serviceMode) {
        // Ring 3: Continuous hardened operation
        Venom::Core::Scheduler scheduler(300);
        scheduler.start(*bus);
    }
    else {
        // One-shot hardened bootstrap
        bus->runAll();
    }

    std::cout << "[SUCCESS] White Venom bootstrap completed successfully."
              << std::endl;

    return 0;
}

