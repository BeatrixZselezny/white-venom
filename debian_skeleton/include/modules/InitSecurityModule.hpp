#pragma once

#include <string>

// MÁR NEM KELL: #include "core/VenomBus.hpp"
// Mivel megszüntettük az IBusModule interfészt.

namespace Venom::Modules {

class InitSecurityModule final { // Nincs többé : public ...
public:
    std::string getName() const {
        return "InitSecurityModule";
    }

    // A régi "run()" helyett, mivel már nincs override
    void execute();
};

}
