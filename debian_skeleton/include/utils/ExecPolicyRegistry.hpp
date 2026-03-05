#pragma once

#include <string>
#include <unordered_map>
#include "utils/ExecPolicy.hpp"

namespace Venom::Security {

class ExecPolicyRegistry {
public:
    static ExecPolicyRegistry& instance();

    void registerPolicy(const std::string& binary,
                        const ExecPolicy& policy);

    const ExecPolicy& getPolicy(const std::string& binary) const;

    void initDefaults();

private:
    ExecPolicyRegistry() = default;

    std::unordered_map<std::string, ExecPolicy> policies;
};

}

