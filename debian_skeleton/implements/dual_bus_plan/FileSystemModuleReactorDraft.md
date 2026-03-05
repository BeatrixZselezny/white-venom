```cpp
// src/modules/FilesystemModule.cpp
// © 2026 Beatrix Zselezny. White-Venom Security.

#include "FilesystemModule.hpp"
#include <iostream>
#include <sys/inotify.h>
#include <sys/epoll.h>
#include <unistd.h>
#include <cstring>
#include <cerrno>

namespace Venom::Modules {

    FilesystemModule::FilesystemModule() {
        // 1. Inotify létrehozása NON-BLOCKING módban!
        // Ez a kulcs, hogy ne fagyjon le a szál.
        inotify_fd = inotify_init1(IN_NONBLOCK);
        if (inotify_fd < 0) {
            perror("[Filesystem] Inotify init failed");
        }

        // 2. Epoll példány létrehozása
        epoll_fd = epoll_create1(0);
        if (epoll_fd < 0) {
            perror("[Filesystem] Epoll init failed");
        }

        // 3. Az inotify FD hozzáadása az epoll figyelési listájához
        struct epoll_event ev;
        ev.events = EPOLLIN; // Olvasásra figyelünk
        ev.data.fd = inotify_fd;
        if (epoll_ctl(epoll_fd, EPOLL_CTL_ADD, inotify_fd, &ev) == -1) {
            perror("[Filesystem] Failed to add inotify to epoll");
        }
    }

    std::string FilesystemModule::getName() const {
        return "Filesystem Sentry (Rx)";
    }

    void FilesystemModule::run() {
        // Itt iratkozunk fel a fájlokra (a policies vektor alapján)
        setupWatches(); 

        std::cout << "[Filesystem] Reactor Loop Started. Watching via epoll..." << std::endl;
        
        struct epoll_event events[10]; // Max 10 esemény egyszerre

        while (true) { // Vagy while(!stopToken)
            // 4. A VÁRAKOZÁS (Venom Tick kompatibilis)
            // 100ms timeout -> Ha nincs semmi, visszaadja a vezérlést,
            // így a Time Cube tudja, hogy élünk, és nem fagyott le a rendszer.
            int nfds = epoll_wait(epoll_fd, events, 10, 100);

            if (nfds == -1) {
                if (errno == EINTR) continue; // Megszakítás, újrapróbáljuk
                perror("[Filesystem] Epoll wait error");
                break;
            }

            // 5. Van kapás?
            if (nfds > 0) {
                // Olvassuk ki az inotify buffert és toljuk a Buszra!
                handleEvents(); 
            }
            
            // Itt a ciklus végén "levegőhöz jut" a szál.
            // Ide jöhet majd a Time Cube "Heartbeat" hívása.
        }
    }

    // ... handleEvents() és setupWatches() implementáció jön még ...
}
```