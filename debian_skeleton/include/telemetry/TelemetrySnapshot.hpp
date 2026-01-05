#pragma once

#include <cstdint>
#include "telemetry/TelemetryTypes.hpp"

struct TelemetrySnapshot {
    uint64_t total;
    uint64_t accepted;
    uint64_t dropped;
    uint64_t null_routed;

    uint32_t queue_current;
    uint32_t queue_peak;

    BusState state;
    uint64_t window_ms;
};

