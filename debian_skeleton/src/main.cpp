#include <iostream>
#include <vector>
#include <string>
#include <filesystem>
#include <unistd.h>
#include "utils/HardeningUtils.hpp"
#include "utils/StringUtils.hpp"
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

bool setup_venom_infrastructure() {
    std::cout << "[T0] Initializing standard infrastructure..." << std::endl;
    std::vector<std::string> secure_paths = {
        "/opt/whitevenom",
        "/opt/whitevenom/bin",
        "/opt/whitevenom/etc",
        "/opt/whitevenom/backups",
        "/run/whitevenom",
        "/var/log/whitevenom"
    };

    for (const auto& path : secure_paths) {
        if (!fs::exists(path)) {
            if (fs::create_directories(path)) {
                fs::permissions(path, fs::perms::owner_all, fs::perm_options::replace);
                std::cout << "[OK] Directory secured: " << path << std::endl;
            }
        }
    }
    return true;
}

void init_rx_bus() {
    std::cout << "[T0] Spawning Dinamikus RX Bus in /run/whitevenom..." << std::endl;
}

int main() {
    std::cout << "--- VENOM ENGINE C++ CORE (LIVE MODE) ---" << std::endl;
    
    // 0. Alapozás
    sterilize_environment();
    if (!setup_venom_infrastructure()) return 1;
    init_rx_bus();

    // 1. Sysctl - Redirect, Link protection, Shared media
    if (VenomUtils::writeProtectedFile("/etc/test_sysctl.conf", VenomTemplates::SYSCTL_BOOTSTRAP_CONTENT)) {
        std::cout << "[OK] Sysctl (Redirect & Link protection) deployed and locked." << std::endl;
    }

    // 2. Blacklist - Kernel modulok tiltása
    if (VenomUtils::writeProtectedFile("/etc/modprobe.d/test_hardening_blacklist.conf", VenomTemplates::BLACKLIST_CONTENT)) {
        std::cout << "[OK] Kernel blacklist deployed and locked." << std::endl;
    }

    // 3. GRUB - CPU mitigations (Spectre/Meltdown)
    if (VenomUtils::writeProtectedFile("/etc/test_grub_default", VenomTemplates::GRUB_HARDENING_CONF)) {
        std::cout << "[OK] GRUB boot-parameters deployed and locked." << std::endl;
    }

    // 4. ÉLES FSTAB AKTIVÁLÁS - hidepid=2, nodev, noexec
    if (VenomUtils::writeProtectedFile("/etc/fstab", VenomTemplates::FSTAB_HARDENING_CONTENT)) {
        std::cout << "[LIVE] /etc/fstab hardened and locked." << std::endl;
    } else {
        std::cerr << "[FAIL] Could not update /etc/fstab!" << std::endl;
    }

    // 5. Make.conf - Toolchain optimalizáció
    if (VenomUtils::writeProtectedFile("/etc/test_make.conf", VenomTemplates::MAKE_CONF_CONTENT)) {
        std::cout << "[OK] make.conf deployed and locked." << std::endl;
    }

    // 6. APT Security (dinamikus http->https csere)
    std::string aptTestPath = "/etc/test_sources.list";
    std::vector<std::string> dummySources = {
        "deb http://deb.debian.org/debian trixie main",
        "deb http://security.debian.org/debian-security trixie-security/updates main"
    };

    std::vector<std::string> secured;
    for (const auto& line : dummySources) {
        secured.push_back(VenomUtils::replaceHttpWithHttps(line));
    }

    if (VenomUtils::writeProtectedFile(aptTestPath, secured)) {
        std::cout << "[OK] APT sources secured with HTTPS and locked." << std::endl;
    }

    std::cout << "[T0] Phase complete. SIG_HW_READY." << std::endl;
    return 0;
}
