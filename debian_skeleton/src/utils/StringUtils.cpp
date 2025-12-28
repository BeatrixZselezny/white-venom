#include "utils/StringUtils.hpp"

namespace VenomUtils {
    std::string replaceAll(std::string str, const std::string& from, const std::string& to) {
        if(from.empty()) return str;
        size_t start_pos = 0;
        while((start_pos = str.find(from, start_pos)) != std::string::npos) {
            str.replace(start_pos, from.length(), to);
            start_pos += to.length();
        }
        return str;
    }

    // Ezt hiányolta a fordító a main.cpp-hez
    std::string replaceHttpWithHttps(const std::string& input) {
        return replaceAll(input, "http://", "https://");
    }
}
