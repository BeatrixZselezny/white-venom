#include "VenomBus.hpp"
#include "SafeExecutor.hpp" // Ring 2 csatolása
#include <iostream>
#include <algorithm>

namespace Venom::Core {

    /**
     * @brief Ring 1: Modul regisztrálása a busz belső névtárába.
     */
    void VenomBus::registerModule(std::shared_ptr<IBusModule> module) {
        if (!module) return;

        auto it = std::find_if(registry.begin(), registry.end(),
            [&module](const std::shared_ptr<IBusModule>& m) {
                return m->getName() == module->getName();
            });

        if (it == registry.end()) {
            registry.push_back(module);
            // Logolás a biztonságos skeletonba (később Logger-rel)
            std::cout << "[VenomBus] Modul regisztrálva: " << module->getName() << std::endl;
        }
    }

    /**
     * @brief Ring 2 Gateway: A SafeExecutor felé néző kapu. 
     * Csak strukturált adatokat (bináris + argumentum vektor) fogad el.
     */
    void VenomBus::dispatchCommand(const std::string& binary, const std::vector<std::string>& args) {
        // A busz a SafeExecutor segítségével hajtatja végre a parancsot
        // shell-mentesen, fork/execv hívással.
        bool success = SafeExecutor::execute(binary, args); 
        
        if (!success) {
            // Hiba esetén kritikus riasztás küldése az audit logba
            std::cerr << "[VenomBus] KRITIKUS: Sikertelen végrehajtás: " << binary << std::endl;
        }
    }

    /**
     * @brief Ring 3: Az ütemező által hívott futtatási ciklus.
     */
    void VenomBus::runAll() {
        for (auto& module : registry) {
            module->run();
        }
    }
}
