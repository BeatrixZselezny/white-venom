#pragma once

#include <atomic>
#include <chrono>
#include <cstdint>

#include "telemetry/TelemetryTypes.hpp"

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

    BusTelemetry();
    void reset_window();
};

