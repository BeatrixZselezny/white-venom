#ifndef STRINGUTILS_HPP
#define STRINGUTILS_HPP

#include <string>

namespace VenomUtils {
    /**
     * @brief Minden előfordulást lecserél a szövegben.
     */
    std::string replaceAll(std::string str, const std::string& from, const std::string& to);
    
    /**
     * @brief Biztonságos HTTPS kényszerítés.
     */
    std::string replaceHttpWithHttps(const std::string& input);

    /**
     * @brief Whitespace eltávolítása a sorok végéről és elejéről (fstab/config tisztítás).
     */
    std::string trim(const std::string& s);
}

#endif
