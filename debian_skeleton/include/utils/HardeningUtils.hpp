#ifndef HARDENINGUTILS_HPP
#define HARDENINGUTILS_HPP

#include <string>
#include <vector>

namespace VenomUtils {
    // DRY_RUN flag a biztonságos teszteléshez
    extern bool DRY_RUN;

    // Fájl írása és auditálása (Zero-Trust)
    bool writeProtectedFile(const std::string& path, const std::vector<std::string>& content);
    
    // Alacsony szintű ioctl hívás a +i flaghez (audit fázishoz)
    bool setImmutable(const std::string& path, bool secure);

    // [ÚJ] Okos FSTAB frissítés UUID védelemmel
    bool smartUpdateFstab(const std::vector<std::string>& hardeningLines);
    
    // [ÚJ] GRUB kernel paraméter injekció (Prepared Statement elv)
    bool injectGrubKernelOpts(const std::string& opts);

    // Biztonságos folyamatindítás (fork + execv)
    bool secureExec(const std::string& binary, const std::vector<std::string>& args);

    // Biztonsági mentés SHA256 integritással
    bool createBackup(const std::string& sourcePath);
}

#endif
