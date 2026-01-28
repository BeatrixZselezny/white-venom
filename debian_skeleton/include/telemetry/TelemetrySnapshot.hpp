#pragma once

#include <cstdint>
#include "telemetry/TelemetryTypes.hpp"

struct TelemetrySnapshot {
    // --- Traffic Metrics (Existing) ---
    uint64_t total;
    uint64_t accepted;
    uint64_t dropped;
    uint64_t null_routed;

    // --- Queue Metrics (Existing) ---
    uint32_t queue_current;
    uint32_t queue_peak;

    // --- System Health (Existing) ---
    BusState state;
    uint64_t window_ms;

    // --- ÚJ: Security Posture (Dual-Venom additions) ---
    SecurityProfile current_profile; // Normal vs High
    uint64_t time_cube_violations;   // Hányszor volt időtúllépés?
    double current_system_load;      // A "Metabolism" load factor (1.0 = normal)
};
