#include "modules/InitSecurityModule.hpp"
#include "utils/ExecPolicyRegistry.hpp"
#include <iostream>

namespace Venom::Modules {

void InitSecurityModule::run() {
    std::cout << "[InitSecurity] Bootstrapping security policies" << std::endl;
    Venom::Security::ExecPolicyRegistry::instance().initDefaults();
}

}

