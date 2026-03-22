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

    // --- Security Posture (Dual-Venom additions) ---
    SecurityProfile current_profile; 
    uint64_t time_cube_violations;   
    double current_system_load;      // A "Metabolism" load factor

    // --- ÚJ: XOR-CAGE & PROFIT (The "Monkey-Tax") ---
    uint64_t entropy_harvested_bytes; // A XOR-spray által finomított adatok mennyisége
    double shannon_index_avg;         // A bejövő dzsuva minősége (0.0 - 8.0)
    double accumulated_venom_gold;    // A visszatépett fillérek virtuális mérőszáma
};
