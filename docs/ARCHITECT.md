┌────────────────────────┐
│  SYSTEM REALITY        │
│                        │
│  (kernel, fs, net,     │
│   modules, sched)      │
└───────────┬────────────┘
            │
            │  történés (event, state change)
            ▼
┌────────────────────────┐
│  TELEMETRY              │
│  (Observable)           │
│                        │
│  • mér                  │
│  • aggregál időben      │
│  • normalizál           │
│  • hallgat              │
└───────────┬────────────┘
            │
            │  kibocsátás (frames, signals)
            ▼
┌────────────────────────┐
│  EMISSION / BUS         │
│  (transport boundary)  │
│                        │
│  • backpressure         │
│  • shape protection     │
│  • isolation            │
└───────────┬────────────┘
            │
            ▼
┌────────────────────────────────────┐
│  OPERATOR CHAIN                     │
│  (RX operators)                     │
│                                    │
│  • window(time)                     │
│  • buffer                           │
│  • map / reduce                     │
│  • scan (stateful)                  │
│                                    │
│  **ITT VAN A GONDOLKODÁS**          │
└───────────┬────────────────────────┘
            │
            ▼
┌────────────────────────┐
│  OBSERVERS              │
│                        │
│  • Time-Cube profiler   │
│  • Scheduler metrics    │
│  • Audit sink           │
└───────────┬────────────┘
            │
            ▼
┌────────────────────────┐
│  SCHEDULERS             │
│  (reaction, routing)   │
└────────────────────────┘



Observable<TelemetryFrame>
    |
    |  (no logic, no policy, no opinion)
    |
    +--> buffer(time)
    |
    +--> window(time_cube)
    |
    +--> map(aggregate)
    |
    +--> scan(profile_state)
    |
    +--> filter(shape_only)
    |
    +--> subscribe(Observer)

