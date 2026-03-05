#pragma once

// Meglévő állapotok
enum class BusState {
    UP,
    DEGRADED,
    OVERLOAD,
    NULL_ONLY
};

// ÚJ: Biztonsági profil állapota (Stream Expectation alapján)
enum class SecurityProfile {
    NORMAL, // Human-scale, predictable [cite: 34]
    HIGH,   // System boot, threat posture [cite: 38]
    LOCKDOWN // Opcionális: teljes zárás
};
