# Global Dependency Map (White Venom)

**Dátum:** 2026-01-18
**Státusz:** HIVATALOSAN BEVEZETVE
**Eszköztár:**
* **Mermaid:** Logikai tervezés (Hogyan *kellene* kinéznie)
* **Doxygen + Graphviz:** Statikus röntgen (Hogyan néz ki *ténylegesen*)

## Döntési jegyzőkönyv
A projekt komplexitása és a Time-Cube Profiling által megkövetelt precizitás miatt a mai naptól kötelező a függőségi gráf használata.
**Cél:** a körkörös függőségek (circular dependencies) elkerülése és a Privilege Separation biztonságos implementálása.

## Jelenlegi logikai gráf (V0.1)

```mermaid
graph TD
    %% Core Layer: A rendszer magja és a jogosultságkezelés
    subgraph Core_Layer
        VB[VenomBus] --> NS[NullScheduler]
        VB --> SE[SafeExecutor]
        SE --> PD[PrivilegeDecision]
        SCH[Scheduler] --> VB
    end

    %% Modules Layer: Funkcionális modulok
    subgraph Modules_Layer
        ISM[InitSecurityModule] --> ER[ExecPolicyRegistry]
        FSM[FilesystemModule] --> HU[HardeningUtils]
    end

    %% Utils Layer: Segédeszközök (Mindenki ezt használja)
    subgraph Utils_Layer
        HU --> ST[StringUtils]
        HU --> CT[ConfigTemplates]
        VI[VenomInitializer] --> HU
    end

    %% Telemetry Layer: Megfigyelés (Csak olvashat, nem írhat vissza a Core-ba)
    subgraph Telemetry_Layer
        VB --> BT[BusTelemetry]
        BT --> TS[TelemetrySnapshot]
    end
    ```
