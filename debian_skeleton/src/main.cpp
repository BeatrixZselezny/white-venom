#include <iostream>
#include <vector>
#include <string>
#include <filesystem>
#include <unistd.h>
#include "utils/HardeningUtils.hpp"
#include "utils/ConfigTemplates.hpp"

namespace fs = std::filesystem;

void sterilize_environment() {
    unsetenv("LD_PRELOAD");
    unsetenv("PYTHONPATH");
    unsetenv("PYTHONHOME");
    unsetenv("LD_LIBRARY_PATH");
    setenv("PATH", "/usr/sbin:/usr/bin:/sbin:/bin", 1);
    std::cout << "[T0] Environment sterilized." << std::endl;
}

int main(int argc, char* argv[]) {
    // Dry-run argumentum kezelése
    for (int i = 1; i < argc; ++i) {
        if (std::string(argv[i]) == "--dry-run") {
            VenomUtils::DRY_RUN = true;
            std::cout << "\n[!] DRY-RUN MODE ACTIVATED - NO CHANGES WILL BE MADE [!]\n" << std::endl;
        }
    }

    std::cout << "--- WHITE VENOM ENGINE - PHASE 0.0-4.0 ---" << std::endl;
    
    sterilize_environment();

    // 0.15 - Sysctl
    VenomUtils::writeProtectedFile("/etc/sysctl.d/99-venom-hardening.conf", VenomTemplates::SYSCTL_BOOTSTRAP_CONTENT);

    // 1.0 - GRUB (CPU Mitigations)
    VenomUtils::injectGrubKernelOpts(VenomTemplates::KERNEL_HARDENING_PARAMS);

    // 1.5 - Blacklist
    VenomUtils::writeProtectedFile("/etc/modprobe.d/hardening_blacklist.conf", VenomTemplates::BLACKLIST_CONTENT);

    // 4.0 - Smart FSTAB
    if (VenomUtils::smartUpdateFstab(VenomTemplates::FSTAB_HARDENING_CONTENT)) {
        std::cout << "[OK] Smart FSTAB update routine complete." << std::endl;
    }

    // 5.0 - Make.conf
    VenomUtils::writeProtectedFile("/etc/make.conf", VenomTemplates::MAKE_CONF_CONTENT);

    std::cout << "\n[SUCCESS] Baseline setup finished. Use --dry-run for audit logs." << std::endl;

    return 0;
}
