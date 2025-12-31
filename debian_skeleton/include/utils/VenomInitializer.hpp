#ifndef VENOM_INITIALIZER_HPP
#define VENOM_INITIALIZER_HPP

#include <string>
#include <vector>
#include <filesystem>

namespace Venom::Init {
    /**
     * @brief Ellenőrzi a root jogosultságot a beavatkozás előtt.
     */
    bool isRoot();

    /**
     * @brief Létrehozza a biztonságos könyvtárstruktúrát szigorú (0700) jogosultságokkal.
     */
    bool createSecureSkeleton();
    
    /**
     * @brief RX-Bus előkészítése (Prepared Statements csatornák a fork/execv hívásokhoz).
     */
    bool setupCommunicationBus();
    
    /**
     * @brief Teljes környezeti sterilizáció (LD_PRELOAD, PATH, stb. tisztítása).
     */
    void purgeUnsafeEnvironment();
}

#endif
