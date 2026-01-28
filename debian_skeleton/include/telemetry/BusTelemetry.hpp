#pragma once

#include <atomic>
#include <chrono>
#include <cstdint>

#include "telemetry/TelemetryTypes.hpp"
#include "telemetry/TelemetrySnapshot.hpp"

struct BusTelemetry {
    // Event counters
    std::atomic<uint64_t> total_events{0};
    std::atomic<uint64_t> accepted_events{0};
    std::atomic<uint64_t> dropped_events{0};
    std::atomic<uint64_t> null_routed_events{0};

    // Queue metrics
    std::atomic<uint32_t> queue_depth{0};
    std::atomic<uint32_t> peak_queue_depth{0};

    // Bus state
    std::atomic<BusState> state{BusState::UP};

    // Time window
    std::chrono::steady_clock::time_point window_start;
    std::chrono::milliseconds window_size{250};

    // ÚJ: Time-Cube specifikus metrikák
    std::atomic<uint64_t> time_cube_violations{0};
    std::atomic<SecurityProfile> current_profile{SecurityProfile::NORMAL};

    // ... függvények ...
    void record_violation() { time_cube_violations++; }
    void set_profile(SecurityProfile p) { current_profile.store(p); }

    BusTelemetry();
    [[nodiscard]] TelemetrySnapshot snapshot() const;
    void reset_window();
};

