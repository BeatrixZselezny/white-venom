// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#ifndef SCHEDULER_HPP
#define SCHEDULER_HPP

#include <thread>
#include <atomic>

namespace Venom::Core {

    // Előzetes deklaráció a fordítási körkörösség elkerülésére
    class VenomBus;

    /**
     * @brief Ring 3: Biztonsági ütemező (A rendszer szívverése).
     */
    class Scheduler {
    private:
        std::atomic<bool> running;
        int intervalSeconds;

    public:
        // Javított inicializálási sorrend a deklaráció szerint
        Scheduler(int seconds = 60) : running(false), intervalSeconds(seconds) {}
        
        // Elindítja a ciklust, ami a Busz runAll() metódusát hívogatja
        void start(VenomBus& bus);
        
        // Ütemező leállítása
        void stop();
    };
}

#endif
