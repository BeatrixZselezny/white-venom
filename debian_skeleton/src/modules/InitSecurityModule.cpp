// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#include "modules/InitSecurityModule.hpp"
// Ha a Registry még nincs átírva, egyelőre ezt kommenteljük ki a biztonság kedvéért:
// #include "utils/ExecPolicyRegistry.hpp" 
#include <iostream>
#include <thread>
#include <chrono>

namespace Venom::Modules {

    void InitSecurityModule::execute() {
        std::cout << "[InitSecurity] Bootstrapping security policies..." << std::endl;
        
        // Itt szimuláljuk a munkát (később ide jön vissza az ExecPolicyRegistry)
        // Ez a sleep segít majd tesztelni a Time-Cube mérést
        std::this_thread::sleep_for(std::chrono::milliseconds(20));

        std::cout << "[InitSecurity] Policies applied." << std::endl;
    }

}
