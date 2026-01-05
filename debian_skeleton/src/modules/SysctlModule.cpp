// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#include "modules/SysctlModule.hpp"
#include "utils/ConfigTemplates.hpp"
#include "utils/HardeningUtils.hpp"
#include <iostream>
#include <fstream>
#include <string>
#include <vector>

namespace Venom::Modules {
    /**
     * @brief A kernel paraméterek érvényesítése natív úton.
     * Mivel a SYSCTL_BOOTSTRAP_CONTENT egy vektor, közvetlenül írjuk a /proc/sys-be.
     */
    void SysctlModule::run() {
        if (VenomUtils::DRY_RUN) {
            std::cout << "[DRY-RUN] SysctlModule: Kernel hardening szimulálása..." << std::endl;
        }

        for (const auto& line : VenomTemplates::SYSCTL_BOOTSTRAP_CONTENT) {
            // Kommentek és üres sorok kihagyása
            if (line.empty() || line[0] == '#') continue;

            size_t pos = line.find('=');
            if (pos != std::string::npos) {
                std::string key = line.substr(0, pos);
                std::string value = line.substr(pos + 1);

                // Pontok cseréje perjelre az útvonalhoz
                for (auto& c : key) if (c == '.') c = '/';
                std::string path = "/proc/sys/" + key;

                if (!VenomUtils::DRY_RUN) {
                    std::ofstream procFile(path);
                    if (procFile.is_open()) {
                        procFile << value;
                        procFile.close();
                    } else {
                        std::cerr << "[ERROR] Nem írható kernel paraméter: " << path << std::endl;
                    }
                } else {
                    std::cout << "[DRY-RUN] Írás: " << path << " -> " << value << std::endl;
                }
            }
        }

        // A fájl alapú perzisztencia biztosítása a VenomUtils segítségével
        VenomUtils::writeProtectedFile("/etc/sysctl.d/99-venom.conf", VenomTemplates::SYSCTL_BOOTSTRAP_CONTENT);
        
        std::cout << "[SUCCESS] SysctlModule: Kernel paraméterek beállítva." << std::endl;
    }
}
