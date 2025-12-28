#ifndef HARDENINGUTILS_HPP
#define HARDENINGUTILS_HPP

#include <string>
#include <vector>

namespace VenomUtils {
    // Fájl írása és azonnali lezárása (Zero-Trust)
    bool writeProtectedFile(const std::string& path, const std::vector<std::string>& content);
    
    // Alacsony szintű ioctl hívás a +i flaghez
    bool setImmutable(const std::string& path, bool secure);
}

#endif
