// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#include "VenomBus.hpp"
#include "SafeExecutor.hpp"               // Ring 2 csatolása
#include "utils/ExecPolicyRegistry.hpp"   // Exec policy enforcement
#include <iostream>
#include <algorithm>

namespace Venom::Core {

    /**
     * @brief Ring 1: Modul regisztrálása a busz belső névtárába.
     */
    void VenomBus::registerModule(std::shared_ptr<IBusModule> module) {
        if (!module) return;

        auto it = std::find_if(
            registry.begin(),
            registry.end(),
            [&module](const std::shared_ptr<IBusModule>& m) {
                return m->getName() == module->getName();
            }
        );

        if (it == registry.end()) {
            registry.push_back(module);
            // Később Logger-rel kiváltjuk
            std::cout << "[VenomBus] Modul regisztrálva: "
                      << module->getName() << std::endl;
        }
    }

    /**
     * @brief Ring 2 Gateway: A SafeExecutor felé néző kapu.
     * Csak policy-vel engedélyezett, strukturált parancsokat hajt végre.
     */
    void VenomBus::dispatchCommand(
        const std::string& binary,
        const std::vector<std::string>& args)
    {
        telemetry.total_events++;

        using Venom::Security::ExecPolicyRegistry;

        // 1️⃣ Exec policy lookup – FAIL CLOSED
        const auto& policy =
            ExecPolicyRegistry::instance().getPolicy(binary);

        // 2️⃣ Strukturális korlátok
        if (args.size() > policy.maxArgs) {
            telemetry.dropped_events++;
            std::cerr << "[VenomBus] POLICY: túl sok argumentum: "
                      << binary << std::endl;
            return;
        }

        for (const auto& a : args) {
            if (a.size() > policy.maxArgLen) {
                telemetry.dropped_events++;
                std::cerr << "[VenomBus] POLICY: túl hosszú argumentum: "
                          << binary << std::endl;
                return;
            }
        }

        // 3️⃣ Szemantikus (binary-specifikus) validáció
        try {
            policy.validate(args);
        } catch (const std::exception& e) {
            telemetry.dropped_events++;
            std::cerr << "[VenomBus] POLICY: validációs hiba: "
                      << e.what() << std::endl;
            return;
        }

        // 4️⃣ Végrehajtás SafeExecutor-rel (változatlan)
        bool success = SafeExecutor::execute(binary, args);

        if (!success) {
            telemetry.dropped_events++;
            std::cerr << "[VenomBus] KRITIKUS: Sikertelen végrehajtás: "
                      << binary << std::endl;
            return;
        }

        telemetry.accepted_events++;
    }

    /**
     * @brief Ring 3: Az ütemező által hívott futtatási ciklus.
     */
    void VenomBus::runAll() {
        for (auto& module : registry) {
            module->run();
        }
    }

    /**
     * @brief Read-only telemetry snapshot lekérése.
     */
    TelemetrySnapshot VenomBus::getTelemetrySnapshot() const {
        return telemetry.snapshot();
    }

} // namespace Venom::Core

