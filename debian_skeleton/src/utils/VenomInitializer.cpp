#include "VenomInitializer.hpp"
#include <iostream>
#include <unistd.h>
#include <sys/stat.h>
#include <filesystem>
#include <vector>

namespace Venom::Init {

    // Kiterjesztett sterilizáció a Zero-Trust elv alapján
    void purgeUnsafeEnvironment() {
        // T0 sterilizáció: minden olyan változó törlése, ami kódinjekcióra adhat okot
        unsetenv("LD_PRELOAD");
        unsetenv("LD_LIBRARY_PATH");
        unsetenv("PYTHONPATH");
        unsetenv("PYTHONHOME");
        
        // Fix, biztonságos PATH kényszerítése
        setenv("PATH", "/usr/sbin:/usr/bin:/sbin:/bin", 1);
    }

    // Root jogosultság ellenőrzése a műveletek előtt
    bool isRoot() {
        return geteuid() == 0;
    }

    bool createSecureSkeleton() {
        if (!isRoot()) {
            std::cerr << "Hiba: A White Venom futtatásához root jogosultság szükséges!" << std::endl;
            return false;
        }

        // A legfontosabb belső könyvtárak, ahol a "méreg" és a mentések laknak
        std::vector<std::string> dirs = {
            "/opt/whitevenom/bin",
            "/opt/whitevenom/etc",
            "/opt/whitevenom/bus",
            "/var/log/Backup" // Szinkronizálva a HardeningUtils-al
        };

        for (const auto& path : dirs) {
            std::error_code ec;
            if (!std::filesystem::exists(path)) {
                if (!std::filesystem::create_directories(path, ec)) {
                    return false;
                }
                
                // Szigorú jogosultság kényszerítése: drwx------ (0700)
                // Csak a root láthatja, mi van benne.
                std::filesystem::permissions(path, 
                                           std::filesystem::perms::owner_all, 
                                           std::filesystem::perm_options::replace);
            }
        }
        return true;
    }
}
