#ifndef HARDENINGUTILS_HPP
#define HARDENINGUTILS_HPP

#include <string>
#include <vector>

namespace VenomUtils {
    // Globális flag a biztonságos teszteléshez
    extern bool DRY_RUN;

    /**
     * @brief ÚJ: A régi ütköző konfigurációk (99-venom*) automatikus eltávolítása.
     */
    void cleanLegacyConfigs();

    /**
     * @brief LD Sanity Check: World-writable könyvtárak keresése (Phase 3.0).
     */
    void checkLDSanity();

    /**
     * @brief Fájl írása Zero-Trust elv alapján (Backup -> Write -> Immutable).
     */
    bool writeProtectedFile(const std::string& path, const std::vector<std::string>& content);
    
    /**
     * @brief Alacsony szintű ioctl hívás az immutable flaghez (Native-First).
     */
    bool setImmutable(const std::string& path, bool secure);

    /**
     * @brief FSTAB frissítés natív C++ feldolgozással.
     */
    bool smartUpdateFstab(const std::vector<std::string>& hardeningLines);
    
    /**
     * @brief GRUB kernel paraméter injekció.
     */
    bool injectGrubKernelOpts(const std::string& opts);

    /**
     * @brief Biztonságos folyamatindítás fork + execv használatával (Prepared Statement).
     */
    bool secureExec(const std::string& binary, const std::vector<std::string>& args);

    /**
     * @brief Biztonsági mentés készítése fájlműveletek előtt.
     */
    bool createBackup(const std::string& sourcePath);
}

#endif
