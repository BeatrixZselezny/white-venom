#ifndef VENOM_INITIALIZER_HPP
#define VENOM_INITIALIZER_HPP

#include <string>
#include <vector>
#include <filesystem>

namespace Venom::Init {
    // Alapvető infrastruktúra felépítése
    bool createSecureSkeleton();
    
    // RX-Bus előkészítése (Prepared Statements csatornák)
    bool setupCommunicationBus();
    
    // Környezet tisztítása (Environment Sterilization)
    void purgeUnsafeEnvironment();
}

#endif
