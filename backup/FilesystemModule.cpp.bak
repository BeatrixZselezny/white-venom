// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#include "modules/FilesystemModule.hpp"
#include "utils/ConfigTemplates.hpp"
#include "utils/HardeningUtils.hpp"
#include <iostream>

namespace Venom::Modules {
    /**
     * @brief Fájlrendszer integritás és kernel modul blacklist kezelése.
     * A projekt szabályai szerint a módosítások előtt a HardeningUtils 
     * gondoskodik a mentésről és a tisztításról.
     */
    void FilesystemModule::run() {
        std::cout << "[Module] FilesystemModule indítása..." << std::endl;

        // 1. Taktikai tisztítás: Régi, inkonzisztens konfigurációk eltávolítása.
        // A HardeningUtils::cleanLegacyConfigs() a /var/backups-ba ment, mielőtt töröl.
        std::cout << "[Step 1] Inkonzisztens /etc/sysctl.d/ fájlok auditálása és takarítása..." << std::endl;
        VenomUtils::cleanLegacyConfigs();

        // 2. Kernel modulok tiltása (modprobe blacklist).
        // A VenomTemplates::BLACKLIST_CONTENT vektor alapján dolgozik.
        std::cout << "[Step 2] Hardening blacklist érvényesítése: /etc/modprobe.d/hardening_blacklist.conf" << std::endl;
        
        // A writeProtectedFile metódus már tartalmazza a DRY_RUN logikát.
        bool blSuccess = VenomUtils::writeProtectedFile(
            "/etc/modprobe.d/hardening_blacklist.conf", 
            VenomTemplates::BLACKLIST_CONTENT
        );

        if (blSuccess) {
            std::cout << "[SUCCESS] Blacklist konfiguráció kezelve." << std::endl;
        } else {
            if (!VenomUtils::DRY_RUN) {
                std::cerr << "[ERROR] Sikertelen írás: /etc/modprobe.d/hardening_blacklist.conf" << std::endl;
            }
        }

        // 3. FSTAB hardening (mount opciók szigorítása).
        // A VenomTemplates::FSTAB_HARDENING_CONTENT vektor alapján.
        std::cout << "[Step 3] /etc/fstab biztonsági integritásának frissítése..." << std::endl;
        
        if (VenomUtils::smartUpdateFstab(VenomTemplates::FSTAB_HARDENING_CONTENT)) {
            std::cout << "[SUCCESS] FSTAB műveletek befejezve." << std::endl;
        } else {
            if (!VenomUtils::DRY_RUN) {
                std::cerr << "[ERROR] Nem sikerült az fstab frissítése." << std::endl;
            }
        }

        std::cout << "[SUCCESS] FilesystemModule folyamatai lefutottak." << std::endl;
    }
}
