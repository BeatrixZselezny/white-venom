#ifndef VENOM_INITIALIZER_HPP
#define VENOM_INITIALIZER_HPP

#include <string>
#include <vector>

namespace Venom::Init {
    /**
     * @brief Ellenőrzi a root jogosultságot (Phase 0.0).
     */
    bool isRoot();

    /**
     * @brief Létrehozza a biztonságos könyvtárstruktúrát (Phase 4.0).
     */
    bool createSecureSkeleton();

    /**
     * @brief Elhelyezi az integritást jelző Canary fájlt (Phase 5.0).
     */
    bool deployCanary();
    
    /**
     * @brief Belső kommunikációs busz (RX-Bus) előkészítése.
     */
    bool setupCommunicationBus();
    
    /**
     * @brief Teljes környezeti sterilizáció (T0).
     * Törli az LD_PRELOAD, PYTHONPATH és egyéb veszélyes változókat.
     */
    void purgeUnsafeEnvironment();
}

#endif
