#ifndef STRINGUTILS_HPP
#define STRINGUTILS_HPP

#include <string>

namespace VenomUtils {
    // A main.cpp által keresett specifikus függvény
    std::string replaceHttpWithHttps(const std::string& input);
    
    // A már meglévő segédfüggvényed
    std::string replaceAll(std::string str, const std::string& from, const std::string& to);
}

#endif
