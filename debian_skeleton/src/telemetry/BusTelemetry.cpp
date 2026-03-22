// © 2026 Beatrix Zselezny. All rights reserved.
// White-Venom Security Framework

#include "telemetry/BusTelemetry.hpp"
#include <chrono>

namespace Venom::Core {

BusTelemetry::BusTelemetry()
    : window_start(std::chrono::steady_clock::now())
{
    // Kezdőértékek inicializálása a szürethealthoz
    entropy_harvested_total.store(0);
    current_shannon_index.store(0.0);
}

void BusTelemetry::reset_window() {
    peak_queue_depth.store(queue_depth.load());
    window_start = std::chrono::steady_clock::now();
}

SystemMetabolism BusTelemetry::get_metabolism() const {
    SystemMetabolism meta;
    
    meta.referenceTickMs = 100.0; 
    
    auto now = std::chrono::steady_clock::now();
    double duration = std::chrono::duration_cast<std::chrono::milliseconds>(now - window_start).count();
    
    uint64_t events = total_events.load();
    meta.currentTickMs = (events > 0) ? (duration / events) : meta.referenceTickMs;
    
    // LoadFactor: Ez adja a "Metabolism" értéket a kijelzőn
    meta.loadFactor = meta.currentTickMs / meta.referenceTickMs;
    
    return meta;
}

TelemetrySnapshot BusTelemetry::snapshot() const {
    TelemetrySnapshot snap{};
    auto metabolism = get_metabolism();

    // Alap statisztikák
    snap.total       = total_events.load();
    snap.accepted    = accepted_events.load();
    snap.dropped     = dropped_events.load();
    snap.null_routed = null_routed_events.load();

    snap.queue_current = queue_depth.load();
    snap.queue_peak    = peak_queue_depth.load();

    snap.state = state.load();
    snap.current_profile = current_profile.load();

    // ÚJ: Itt adjuk át a "majom-vám" adatait a snapshotnak
    snap.current_system_load = metabolism.loadFactor;
    snap.entropy_harvested_bytes = entropy_harvested_total.load();
    snap.shannon_index_avg = current_shannon_index.load();
    
    // Elméleti arany számítás (példa logika: entrópia + mennyiség alapján)
    snap.accumulated_venom_gold = (snap.entropy_harvested_bytes / 1024.0) * snap.shannon_index_avg;

    snap.window_ms =
        std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now() - window_start
        ).count();

    return snap;
}

} // namespace Venom::Core
