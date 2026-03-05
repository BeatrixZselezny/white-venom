// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#include "utils/StringUtils.hpp"
#include <algorithm>

namespace VenomUtils {
    // Hatékonyabb implementáció const ref-el az elején
    std::string replaceAll(std::string str, const std::string& from, const std::string& to) {
        if(from.empty()) return str;
        size_t start_pos = 0;
        while((start_pos = str.find(from, start_pos)) != std::string::npos) {
            str.replace(start_pos, from.length(), to);
            start_pos += to.length();
        }
        return str;
    }

    // Modernizált, tiszta implementáció
    std::string replaceHttpWithHttps(const std::string& input) {
        if (input.empty()) return "";
        return replaceAll(input, "http://", "https://");
    }

    // ÚJ: Whitespace tisztító a biztonságos parsinghoz (pl. fstab szóközök ellen)
    std::string trim(const std::string& s) {
        auto wsfront = std::find_if_not(s.begin(), s.end(), [](int c){return std::isspace(c);});
        auto wsback = std::find_if_not(s.rbegin(), s.rend(), [](int c){return std::isspace(c);}).base();
        return (wsback <= wsfront ? "" : std::string(wsfront, wsback));
    }
}
