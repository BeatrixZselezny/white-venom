// src/utils/ExecPolicyRegistry.cpp

#include "utils/ExecPolicyRegistry.hpp"
#include "utils/SysctlPolicy.hpp"

#include <stdexcept>

namespace Venom::Security {

ExecPolicyRegistry& ExecPolicyRegistry::instance() {
    static ExecPolicyRegistry inst;
    return inst;
}

void ExecPolicyRegistry::registerPolicy(const std::string& binary,
                                        const ExecPolicy& policy) {
    policies.emplace(binary, policy);
}

const ExecPolicy& ExecPolicyRegistry::getPolicy(const std::string& binary) const {
    auto it = policies.find(binary);
    if (it == policies.end()) {
        throw std::runtime_error("No ExecPolicy registered for binary: " + binary);
    }
    return it->second;
}

void ExecPolicyRegistry::initDefaults() {
    registerPolicy(
        "/sbin/sysctl",
        ExecPolicy{
            .maxArgs   = 32,
            .maxArgLen = 128,
            .validate  = [](const std::vector<std::string>& args) {
                validateSysctlArgs(args);
            }
        }
    );
}

} // namespace Venom::Security

