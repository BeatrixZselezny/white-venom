#ifndef FILESYSTEM_MODULE_HPP
#define FILESYSTEM_MODULE_HPP

#include "core/VenomBus.hpp"
#include <string>

namespace Venom::Modules {
    /**
     * @brief Modul a fájlrendszer hardening és modul blacklist feladatokhoz.
     */
    class FilesystemModule : public Venom::Core::IBusModule {
    public:
        /**
         * @brief Visszaadja a modul nevét a busz számára.
         */
        std::string getName() const override { return "FilesystemHardening"; }

        /**
         * @brief Végrehajtja a tisztítást, a blacklist írását és az fstab frissítését.
         */
        void run() override;
    };
}

#endif
