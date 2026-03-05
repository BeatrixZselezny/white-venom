#ifndef BUS_TELEMETRY_HPP
#define BUS_TELEMETRY_HPP

#include <atomic>
#include <chrono>
#include "telemetry/TelemetrySnapshot.hpp"
#include "TimeCubeTypes.hpp" // FIX: Közvetlenül az include-ban van!

namespace Venom::Core {

    struct BusTelemetry {
        std::atomic<uint64_t> total_events{0};
        std::atomic<uint64_t> accepted_events{0};
        std::atomic<uint64_t> null_routed_events{0};
        std::atomic<uint64_t> dropped_events{0};
        std::atomic<uint32_t> queue_depth{0};
        std::atomic<uint32_t> peak_queue_depth{0};
        std::atomic<BusState> state{BusState::UP};
        std::atomic<SecurityProfile> current_profile{SecurityProfile::NORMAL};

        std::chrono::steady_clock::time_point window_start;

        BusTelemetry();
        void reset_window();
        
        // Ez kell a metabolikus méréshez
        SystemMetabolism get_metabolism() const;
        
        TelemetrySnapshot snapshot() const;
    };

} // namespace Venom::Core

#endif
