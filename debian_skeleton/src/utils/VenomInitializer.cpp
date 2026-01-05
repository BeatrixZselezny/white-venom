// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#include "VenomInitializer.hpp"
#include "utils/HardeningUtils.hpp"
#include "utils/ConfigTemplates.hpp"
#include <iostream>
#include <unistd.h>
#include <filesystem>
#include <vector>
#include <cstdlib>

namespace fs = std::filesystem;

namespace Venom::Init {

    bool isRoot() {
        return geteuid() == 0;
    }

    void purgeUnsafeEnvironment() {
        // Kritikus változók törlése a kódinjekció és Python függőség ellen
        std::vector<std::string> blacklist = {
            "LD_PRELOAD", "LD_LIBRARY_PATH", "PYTHONPATH", "PERL5LIB", "IFS"
        };
        for (const auto& var : blacklist) {
            unsetenv(var.c_str());
        }
    }

    bool createSecureSkeleton() {
        if (VenomUtils::DRY_RUN) return true;

        std::vector<std::string> secureDirs = {
            "/var/log/whitevenom", "/var/log/Backup", "/etc/venom", "/run/venom"
        };

        try {
            for (const auto& dir : secureDirs) {
                if (!fs::exists(dir)) {
                    fs::create_directories(dir);
                }
                // Csak root: rwx------ (0700)
                fs::permissions(dir, fs::perms::owner_all, fs::perm_options::replace);
            }
            return true;
        } catch (const std::exception& e) {
            std::cerr << "[ERROR] Skeleton failed: " << e.what() << std::endl;
            return false;
        }
    }

    bool deployCanary() {
        const std::string path = "/etc/venom/integrity.canary";
        if (VenomUtils::writeProtectedFile(path, VenomTemplates::CANARY_CONTENT)) {
            return VenomUtils::setImmutable(path, true);
        }
        return false;
    }
}
