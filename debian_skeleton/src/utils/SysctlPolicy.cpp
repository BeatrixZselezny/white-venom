#include "utils/SysctlPolicy.hpp"
#include <stdexcept>

namespace Venom::Security {

void validateSysctlArgs(const std::vector<std::string>& args) {
    for (const auto& a : args) {
        if (a.find('=') == std::string::npos)
            throw std::runtime_error("sysctl arg must be key=value");

        if (a.find(';') != std::string::npos ||
            a.find('&') != std::string::npos ||
            a.find('|') != std::string::npos)
            throw std::runtime_error("illegal character in sysctl arg");
    }
}

}

