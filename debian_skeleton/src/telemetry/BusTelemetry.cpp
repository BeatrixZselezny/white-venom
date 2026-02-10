// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#include "telemetry/BusTelemetry.hpp"

BusTelemetry::BusTelemetry()
    : window_start(std::chrono::steady_clock::now())
{
}

void BusTelemetry::reset_window() {
    peak_queue_depth.store(queue_depth.load());
    window_start = std::chrono::steady_clock::now();
}

TelemetrySnapshot BusTelemetry::snapshot() const {
    TelemetrySnapshot snap{};

    snap.total       = total_events.load();
    snap.accepted    = accepted_events.load();
    snap.dropped     = dropped_events.load();
    snap.null_routed = null_routed_events.load();

    snap.queue_current = queue_depth.load();
    snap.queue_peak    = peak_queue_depth.load();

    snap.state = state.load();
    
    // Itt adjuk át az aktuális profilt a snapshotnak
    snap.current_profile = current_profile.load();

    snap.window_ms =
        std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now() - window_start
        ).count();

    return snap;
}
