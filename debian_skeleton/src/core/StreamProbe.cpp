// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#include "core/StreamProbe.hpp"
#include <map>
#include <cmath>
#include <algorithm>

namespace Venom::Core {

    /**
     * @brief Shannon-entrópia számítása az adatfolyamon.
     * Segít megkülönböztetni a strukturált szöveget a titkosított/bináris zajtól.
     */
    double StreamProbe::calculateEntropy(const std::string& data) {
        if (data.empty()) {
            return 0.0;
        }

        std::map<unsigned char, size_t> frequencies;
        for (unsigned char c : data) {
            frequencies[c]++;
        }

        double entropy = 0.0;
        for (auto const& [val, count] : frequencies) {
            double p = static_cast<double>(count) / data.size();
            entropy -= p * std::log2(p);
        }

        return entropy;
    }

    /**
     * @brief Zero-Trust alapú típusdetektálás.
     * Ha az entrópia túl magas a profilhoz képest, az adatot gyanúsnak jelöljük.
     */
    DataType StreamProbe::detectZeroTrust(const std::string& data, SecurityProfile profile) {
        if (data.empty()) {
            return DataType::UNKNOWN;
        }

        // 1. Bináris jelleg ellenőrzése (nem nyomtatható karakterek aránya)
        size_t nonPrintable = 0;
        for (unsigned char c : data) {
            if (c < 32 && c != '\n' && c != '\r' && c != '\t') {
                nonPrintable++;
            }
        }

        double entropy = calculateEntropy(data);
        
        // Küszöbértékek a biztonsági profil alapján
        double threshold = (profile == SecurityProfile::HIGH) ? 5.8 : 6.8;

        if (entropy > threshold || (static_cast<double>(nonPrintable) / data.size() > 0.3)) {
            return DataType::BINARY;
        }

        // 2. Formátum felismerés (egyszerűsített JSON/Text döntés)
        if (data.find('{') != std::string::npos && data.find('}') != std::string::npos) {
            if (data.find(':') != std::string::npos) {
                return DataType::JSON;
            }
        }

        return DataType::TEXT;
    }

} // namespace Venom::Core
