#include "telemetry/BusTelemetry.hpp"

BusTelemetry::BusTelemetry() {
    window_start = std::chrono::steady_clock::now();
}

void BusTelemetry::reset_window() {
    peak_queue_depth.store(queue_depth.load());
    window_start = std::chrono::steady_clock::now();
}

