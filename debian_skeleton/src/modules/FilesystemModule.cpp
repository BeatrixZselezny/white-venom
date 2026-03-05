// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#include "modules/FilesystemModule.hpp"
#include <filesystem>
#include <iostream>
#include <unistd.h>
#include <sys/inotify.h>
#include <sys/select.h>
#include <cerrno>
#include <cstring>

namespace fs = std::filesystem;

// Inotify buffer méret
constexpr size_t EVENT_SIZE = sizeof(struct inotify_event);
constexpr size_t BUF_LEN = 1024 * (EVENT_SIZE + 16);

namespace Venom::Modules {

FilesystemModule::FilesystemModule(Venom::Core::VenomBus& busRef) 
    : bus(busRef), inotifyFd(-1), keepMonitoring(false) {
    
    // Policy-k definiálása (most már watch flaggel)
    policies = {
        { "/etc",   true, true,  false, true }, // Figyeljük!
        { "/var",   true, true,  false, false },
        { "/tmp",   true, true,  true,  true }, // Figyeljük!
        { "/home",  true, true,  false, false }
    };
}

FilesystemModule::~FilesystemModule() {
    stopMonitoring();
}

std::string FilesystemModule::getName() const {
    return "FilesystemModule";
}

void FilesystemModule::performStaticAudit() {
    for (const auto& policy : policies) {
        auditPath(policy);
    }
}

void FilesystemModule::auditPath(const FilesystemPathPolicy& policy) {
    fs::path p(policy.path);

    // Események "push"-olása ahelyett, hogy std::cerr-re írnánk
    if (!fs::exists(p)) {
        if (policy.mustExist) {
            bus.pushEvent("FS_AUDIT", "MISSING_PATH: " + policy.path);
        }
        return;
    }

    if (policy.mustBeDirectory && !fs::is_directory(p)) {
        bus.pushEvent("FS_AUDIT", "TYPE_MISMATCH: " + policy.path);
        return;
    }

    auto perms = fs::status(p).permissions();
    bool worldWritable = (perms & fs::perms::others_write) != fs::perms::none;

    if (!policy.allowWorldWrite && worldWritable) {
        bus.pushEvent("FS_AUDIT", "WORLD_WRITABLE: " + policy.path);
    }
}

void FilesystemModule::startMonitoring() {
    if (keepMonitoring) return; // Már fut

    inotifyFd = inotify_init();
    if (inotifyFd < 0) {
        bus.pushEvent("FS_ERROR", "Inotify init failed");
        return;
    }

    // Figyelők hozzáadása
    for (const auto& policy : policies) {
        if (policy.watchRealTime && fs::exists(policy.path)) {
            int wd = inotify_add_watch(inotifyFd, policy.path.c_str(), IN_CREATE | IN_DELETE | IN_MODIFY);
            if (wd >= 0) {
                watchDescriptors.push_back(wd);
                // Opcionális: jelezzük a buszon, hogy figyelünk
                // bus.pushEvent("FS_INFO", "Watching: " + policy.path);
            }
        }
    }

    keepMonitoring = true;
    monitorThread = std::thread(&FilesystemModule::monitorLoop, this);
}

void FilesystemModule::stopMonitoring() {
    keepMonitoring = false;
    
    if (inotifyFd >= 0) {
        close(inotifyFd); // Ez felébreszti a read-et hibával
        inotifyFd = -1;
    }

    if (monitorThread.joinable()) {
        monitorThread.join();
    }
}

void FilesystemModule::monitorLoop() {
    char buffer[BUF_LEN];

    while (keepMonitoring) {
        // Blokkoló olvasás, de mivel külön szálon van, nem fagyasztja a rendszert
        // Egy select() vagy poll() timeouttal elegánsabb lenne a leállításhoz, 
        // de most a read() hibára (close) hagyatkozunk.
        
        fd_set fds;
        FD_ZERO(&fds);
        FD_SET(inotifyFd, &fds);
        
        // Rövid timeout, hogy ellenőrizhessük a keepMonitoring flaget
        struct timeval tv = {1, 0}; // 1 sec
        
        int ret = select(inotifyFd + 1, &fds, NULL, NULL, &tv);
        
        if (ret > 0) {
            int length = read(inotifyFd, buffer, BUF_LEN);
            if (length < 0) break;

            int i = 0;
            while (i < length) {
                struct inotify_event* event = (struct inotify_event*)&buffer[i];
                
                if (event->len) {
                    std::string filename = event->name;
                    std::string type;
                    
                    if (event->mask & IN_CREATE) type = "CREATED";
                    else if (event->mask & IN_DELETE) type = "DELETED";
                    else if (event->mask & IN_MODIFY) type = "MODIFIED";
                    else type = "UNKNOWN";

                    // BEDOBJUK A VENT BUS-BA! 👁️ -> 🧠
                    bus.pushEvent("FS_WATCH", type + ": " + filename);
                }
                i += EVENT_SIZE + event->len;
            }
        } else if (ret < 0 && errno != EINTR) {
            // Hiba
            break;
        }
    }
}

} // namespace Venom::Modules
