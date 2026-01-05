// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#ifndef SYSCTL_MODULE_HPP
#define SYSCTL_MODULE_HPP

#include "core/VenomBus.hpp"
#include <string>

namespace Venom::Modules {

    /**
     * @brief Natív Kernel Hardening Modul.
     * Közvetlenül a /proc/sys fájlrendszeren keresztül konfigurálja a kernelt,
     * elkerülve a külső sysctl bináris hívását. 
     */
    class SysctlModule : public Venom::Core::IBusModule {
    public:
        std::string getName() const override { return "SysctlHardening"; }
        
        /**
         * @brief A kernel paraméterek érvényesítése natív C++ úton.
         */
        void run() override;
    };
}

#endif
