#include <iostream>
#include "VenomInitializer.hpp"
#include "utils/HardeningUtils.hpp"
#include "utils/ConfigTemplates.hpp"

int main(int argc, char* argv[]) {
    for (int i = 1; i < argc; ++i) {
        if (std::string(argv[i]) == "--dry-run") VenomUtils::DRY_RUN = true;
    }

    // T0: Sterilizáció
    Venom::Init::purgeUnsafeEnvironment();
    
    if (!Venom::Init::isRoot()) return 1;

    // Fázisok futtatása natív hívásokkal
    if (VenomUtils::writeProtectedFile("/etc/sysctl.d/99-venom.conf", VenomTemplates::SYSCTL_BOOTSTRAP_CONTENT)) {
        VenomUtils::secureExec("/usr/sbin/sysctl", {"--system"});
    }

    VenomUtils::checkLDSanity();
    Venom::Init::createSecureSkeleton();
    
    // Make.conf és Canary elhelyezése
    VenomUtils::writeProtectedFile("/etc/make.conf", VenomTemplates::MAKE_CONF_CONTENT);
    Venom::Init::deployCanary();

    std::cout << "[SUCCESS] White Venom hardened engine finished." << std::endl;
    return 0;
}
