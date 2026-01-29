// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#ifndef FILESYSTEM_MODULE_HPP
#define FILESYSTEM_MODULE_HPP

#include "core/VenomBus.hpp"
#include <string>
#include <vector>
#include <thread>
#include <atomic>

namespace Venom::Modules {

    struct FilesystemPathPolicy {
        std::string path;
        bool mustExist       = true;
        bool mustBeDirectory = true;
        bool allowWorldWrite = false;
        bool watchRealTime   = false; // Új mező: figyeljük-e inotify-val?
    };

    class FilesystemModule {
    public:
        // Dependency Injection: Kötelező a Bus megadása
        explicit FilesystemModule(Venom::Core::VenomBus& busRef);
        ~FilesystemModule();

        std::string getName() const;

        // A régi statikus ellenőrzés (Scan)
        void performStaticAudit();

        // Az új valós idejű figyelés (Eyes open)
        void startMonitoring();
        void stopMonitoring();

    private:
        Venom::Core::VenomBus& bus; // Referencia a központi idegrendszerre
        std::vector<FilesystemPathPolicy> policies;

        // Inotify változók
        int inotifyFd;
        std::atomic<bool> keepMonitoring;
        std::thread monitorThread;
        std::vector<int> watchDescriptors;

        void auditPath(const FilesystemPathPolicy& policy);
        void monitorLoop(); // A háttérszál függvénye
    };

}

#endif
