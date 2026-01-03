#ifndef VENOM_BUS_HPP
#define VENOM_BUS_HPP

#include <vector>
#include <memory>
#include <string>

namespace Venom::Core {

    /**
     * @brief Absztrakt alaposztály minden modulnak.
     */
    class IBusModule {
    public:
        virtual ~IBusModule() = default;
        virtual std::string getName() const = 0;
        virtual void run() = 0; 
    };

    /**
     * @brief Ring 1: A központi kommunikációs busz és modulregiszter.
     */
    class VenomBus {
    private:
        std::vector<std::shared_ptr<IBusModule>> registry;

    public:
        // Modul regisztrálása a buszon
        void registerModule(std::shared_ptr<IBusModule> module);
        
        // A SafeExecutor felé néző biztonságos kapu
        void dispatchCommand(const std::string& binary, const std::vector<std::string>& args);

        // Ring 3: Az összes regisztrált modul futtatása
        void runAll();
    };
}

#endif
