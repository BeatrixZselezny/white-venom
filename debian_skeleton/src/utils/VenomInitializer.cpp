#include "VenomInitializer.hpp"
#include <iostream>
#include <unistd.h>
#include <sys/stat.h>

namespace Venom::Init {
    void purgeUnsafeEnvironment() {
        // T0 sterilizáció a 00_install.sh alapján
        unsetenv("LD_PRELOAD");
        unsetenv("PYTHONPATH");
        setenv("PATH", "/usr/sbin:/usr/bin:/sbin:/bin", 1);
    }

    bool createSecureSkeleton() {
        std::vector<std::string> dirs = {
            "/opt/whitevenom/bin",
            "/opt/whitevenom/etc",
            "/opt/whitevenom/bus",
            "/opt/whitevenom/backups"
        };

        for (const auto& path : dirs) {
            std::error_code ec;
            if (!std::filesystem::exists(path)) {
                if (!std::filesystem::create_directories(path, ec)) return false;
                // Jogosultság kényszerítése: drwx------
                std::filesystem::permissions(path, std::filesystem::perms::owner_all, 
                                           std::filesystem::perm_options::replace);
            }
        }
        return true;
    }
}
