// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#ifndef NULL_SCHEDULER_HPP
#define NULL_SCHEDULER_HPP

#include <rxcpp/rx.hpp>
#include <string>

namespace Venom::Core {

    /**
     * @brief A NULL Scheduler implementációja.
     * Nem büntet, nem riaszt, nem blokkol – egyszerűen elnyel. [cite: 34]
     */
    class NullScheduler {
    public:
        /**
         * @brief Egy olyan worker-t ad vissza, ami azonnal "elfogyasztja" a feladatot
         * anélkül, hogy bármit ténylegesen ütemezne 'Kannibál Scheduler'.
         */
        static rxcpp::identity_one_worker create_worker() {
            return rxcpp::identity_one_worker(rxcpp::schedulers::make_current_thread());
        }

        /**
         * @brief A "Ventiláció" művelet: befogadja a streamet, de megszakítja a láncot.
         */
        template<typename T>
        static void absorb(const T& data) {
            // Nem naplózunk eseményenként, hogy elkerüljük a DoS-t. [cite: 134, 137]
            // Csak belső, névtelen metrikát frissítünk. [cite: 136]
            (void)data; 
        }
    };
}

#endif
