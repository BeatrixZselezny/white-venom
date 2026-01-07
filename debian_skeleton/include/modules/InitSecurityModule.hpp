#pragma once

#include "core/VenomBus.hpp"
#include <string>

namespace Venom::Modules {

class InitSecurityModule final : public Venom::Core::IBusModule {
public:
    std::string getName() const override {
        return "InitSecurityModule";
    }

    void run() override;
};

}

