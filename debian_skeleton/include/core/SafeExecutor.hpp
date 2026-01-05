// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#ifndef SAFE_EXECUTOR_HPP
#define SAFE_EXECUTOR_HPP

#include <string>
#include <vector>

namespace Venom::Core {
    class SafeExecutor {
    public:
        /**
         * @brief A "Prepared Statement" logika: bináris és argumentum vektor szétválasztva.
         * Megfelel a projekt biztonsági előírásainak (fork/execv).
         */
        static bool execute(const std::string& binary, const std::vector<std::string>& args);
    };
}

#endif
