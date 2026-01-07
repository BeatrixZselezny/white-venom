// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#include "modules/FilesystemModule.hpp"
#include <filesystem>
#include <iostream>

namespace fs = std::filesystem;

namespace Venom::Modules {

FilesystemModule::FilesystemModule() {
    // Minimalista default policy-k
    policies = {
        { "/etc",   true, true,  false },
        { "/var",   true, true,  false },
        { "/tmp",   true, true,  true  },
        { "/home",  true, true,  false }
    };
}

std::string FilesystemModule::getName() const {
    return "FilesystemModule";
}

void FilesystemModule::run() {
    for (const auto& policy : policies) {
        auditPath(policy);
    }
}

void FilesystemModule::auditPath(const FilesystemPathPolicy& policy) {
    fs::path p(policy.path);

    if (!fs::exists(p)) {
        if (policy.mustExist) {
            std::cerr << "[FS] HIÁNYZÓ útvonal: " << policy.path << std::endl;
        }
        return;
    }

    if (policy.mustBeDirectory && !fs::is_directory(p)) {
        std::cerr << "[FS] Nem könyvtár: " << policy.path << std::endl;
        return;
    }

    auto perms = fs::status(p).permissions();

    bool worldWritable =
        (perms & fs::perms::others_write) != fs::perms::none;

    if (!policy.allowWorldWrite && worldWritable) {
        std::cerr << "[FS] World-writable útvonal: " << policy.path << std::endl;
    }
}

} // namespace Venom::Modules

