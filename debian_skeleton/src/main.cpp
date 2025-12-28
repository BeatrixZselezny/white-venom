#include <iostream>
#include <vector>
#include <string>
#include "utils/HardeningUtils.hpp"
#include "utils/StringUtils.hpp"

int main() {
    std::cout << "--- VENOM ENGINE C++ CORE ---" << std::endl;
    std::cout << "[INIT] Zero-Trust environment active." << std::endl;

    // 1. Hardening Blacklist Config (Teszt fájl az /etc-ben)
    //
    std::string blPath = "/etc/modprobe.d/test_hardening_blacklist.conf";
    std::vector<std::string> blContent = {
        "blacklist usb-storage",
        "blacklist firewire-core",
        "blacklist thunderbolt",
        "install dccp /bin/true",
        "install sctp /bin/true"
    };

    if (VenomUtils::writeProtectedFile(blPath, blContent)) {
        std::cout << "[OK] Kernel blacklist deployed and locked." << std::endl;
    } else {
        std::cout << "[FAIL] Kernel blacklist deployment failed." << std::endl;
    }

    // 2. Make.conf Config (Teszt fájl az /etc-ben)
    //
    std::string mcPath = "/etc/test_make.conf";
    std::vector<std::string> mcContent = {
        "COMMON_FLAGS=\"-O2 -pipe -fstack-protector-strong -D_FORTIFY_SOURCE=2\"",
        "CHOST=\"x86_64-pc-linux-gnu\"",
        "USE=\"hardened nosuspnd no-python -unbound\"",
        "ACCEPT_LICENSE=\"*\""
    };

    if (VenomUtils::writeProtectedFile(mcPath, mcContent)) {
        std::cout << "[OK] make.conf deployed and locked." << std::endl;
    } else {
        std::cout << "[FAIL] make.conf deployment failed." << std::endl;
    }

    // 3. APT HTTPS Enforcement (Teszt funkció a VenomUtils::replaceHttpWithHttps használatával)
    //
    std::string aptTestPath = "/etc/test_sources.list";
    std::vector<std::string> dummySources = {
        "deb http://deb.debian.org/debian trixie main",
        "deb http://security.debian.org/debian-security trixie-security main"
    };

    std::vector<std::string> securedSources;
    for (const auto& line : dummySources) {
        // Itt a javítás: VenomUtils névtér használata a StringUtils-hoz
        securedSources.push_back(VenomUtils::replaceHttpWithHttps(line));
    }

    if (VenomUtils::writeProtectedFile(aptTestPath, securedSources)) {
        std::cout << "[OK] APT sources (test) secured with HTTPS and locked." << std::endl;
    } else {
        std::cout << "[FAIL] APT sources securing failed." << std::endl;
    }

    return 0;
}
