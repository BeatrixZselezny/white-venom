// include/utils/ExecPolicy.hpp
#pragma once

#include <string>
#include <vector>
#include <functional>

namespace Venom::Security {

struct ExecPolicy {
    size_t maxArgs;
    size_t maxArgLen;

    // Strukturális + szemantikus validáció
    std::function<void(const std::vector<std::string>&)> validate;
};

}

