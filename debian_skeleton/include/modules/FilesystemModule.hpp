// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#ifndef FILESYSTEM_MODULE_HPP
#define FILESYSTEM_MODULE_HPP

#include "core/VenomBus.hpp"
#include <string>
#include <vector>

namespace Venom::Modules {

    struct FilesystemPathPolicy {
        std::string path;
        bool mustExist       = true;
        bool mustBeDirectory = true;
        bool allowWorldWrite = false;
    };

    class FilesystemModule : public Venom::Core::IBusModule {
    public:
        FilesystemModule();

        std::string getName() const override;
        void run() override;

    private:
        std::vector<FilesystemPathPolicy> policies;

        void auditPath(const FilesystemPathPolicy& policy);
    };

}

#endif

