// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework
// Zero-Trust Stream Analysis & Entropy Evaluation

#ifndef STREAM_PROBE_HPP
#define STREAM_PROBE_HPP

#include <string>
#include <vector>
#include "TimeCubeTypes.hpp" // A SecurityProfile definíció miatt

namespace Venom::Core {

    /**
     * @brief A rendszer adat-osztályozása.
     * UNKNOWN: Alapértelmezett állapot, amíg a vizsgálat tart. [cite: 19, 24]
     */
    enum class DataType { 
        TEXT,    // Emberi léptékű szöveg, parancsok [cite: 15, 20]
        JSON,    // Strukturált konfigurációk [cite: 16, 21]
        METRIC,  // Numerikus telemetria [cite: 17, 22]
        BINARY,  // Opaque adathalmazok, potenciálisan veszélyes [cite: 18, 23]
        UNKNOWN  // Eldönthetetlen vagy sérült [cite: 19, 24]
    };

    /**
     * @brief Könnyűsúlyú viselkedési szonda.
     * Nem végez mély elemzést (deep parsing), nem allokál nehéz objektumokat. [cite: 59]
     */
    class StreamProbe {
    public:
        /**
         * @brief Zero-Trust alapú típusfelismerés.
         * @param data A vizsgálandó nyers adat.
         * @param profile Az aktuális biztonsági profil (NORMAL/HIGH). [cite: 33]
         * @return A detektált DataType.
         */
        static DataType detectZeroTrust(const std::string& data, SecurityProfile profile);

        /**
         * @brief Shannon-entrópia számítás.
         * Segít felismerni a titkosított csatornákat vagy a tömörített adatokat.
         */
        static double calculateEntropy(const std::string& data);

    private:
        // Belső segéd a karakterek validálásához (UTF-8/Ékezet barát)
        static bool isControlCharacter(unsigned char c) {
            // Megengedjük az újsort, tabot, de tiltjuk a bináris vezérlőket
            return (c < 32 && c != '\n' && c != '\r' && c != '\t');
        }
    };

} // namespace Venom::Core

#endif // STREAM_PROBE_HPP
