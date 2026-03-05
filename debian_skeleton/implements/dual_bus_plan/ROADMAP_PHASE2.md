# White-Venom Roadmap: Phase 2 - Awakening the Beast
**Dátum:** 2026.01.28.
**Status:** Phase 1 Complete (Core Stable)
**Következő lépés:** Perifériák és Logika Integrációja

## 🏁 Jelenlegi Állapot (Milestone 1)
A rendszer magja (**Dual-Venom Core**) sikeresen elkészült és stabil.
* **Architektúra:** Dual-Bus Reactive (RxCpp)
* **Vent Bus:** Adatfogadás és pufferelés működik.
* **Cortex Bus:** Vezérlés és végrehajtás működik.
* **Scheduler:** A párhuzamos szálkezelés (Worker Pool + Dedicated Thread) és a tiszta leállítás (Graceful Shutdown) üzemel.

### Proof of Life (Logrészlet)
```text
[Init] White Venom Engine v2.0 (Dual-Bus Reactive)
[Scheduler] Dual-Bus Engines Starting...
[VenomBus] Reaktív pipeline felépítve: Vent -> Cortex
[Mode] Service Mode Started. Listening on Vent Bus...
[Status] Q: 0 | Events: 306 | Profile: NORMAL
[Signal] Leállítási kérelem...
[Shutdown] Cleaning up...
```
## Phase 2 Tervezet: "Senses & Brain"

A következő fejlesztési szakasz célja a rendszer "érzékszerveinek" (modulok) és "agyának" (Time-Cube) bekapcsolása.
1. Lépés: A Szemek Visszakapcsolása (FilesystemModule) 👁️

A fájlrendszer-figyelő modul jelenleg ki van kapcsolva. Át kell írnunk a régi imperatív kódot az új reaktív logikára.

- Feladat: src/modules/FilesystemModule.cpp refaktorálása.
- Változás: Az inotify eseményeket a bus.pushEvent() metódussal kell a Vent csőbe irányítani a közvetlen feldolgozás helyett.
- Cél: Valós fájlrendszer-események megjelenése a Dashboard számlálóján.

2. Lépés: Time-Cube Kalibráció (The Venom Tick) ⏳

A rendszernek ismernie kell a saját sebességét a relatív időméréshez.

- Feladat: CalibrationManager osztály implementálása.
- Működés: Induláskor lefuttat egy mikro-benchmarkot, és beállítja a SystemMetabolism értékét.
- Cél: A lassú gépeken ne legyen hamis riasztás (False Positive), a gyors gépeken pedig szigorúbb legyen a védelem.

3. Lépés: A Pajzs (Stream Probe & Policy) 🛡️

A VenomBus jelenleg minden adatot átenged (dummy logic). Be kell építeni a szűrőt.
Feladat: A StreamProbe logika implementálása a VenomBus.cpp map/filter láncába.

Működés:

- Események elemzése (gyakoriság, minta).
- Döntés: NORMAL -> HIGH profilváltás gyanús aktivitás esetén.
- Túlterhelés esetén Null Routing (csomageldobás).

Technikai Teendők (Next Session)

- src/modules/FilesystemModule.hpp tisztítása (IBusModule öröklés törlése).
- src/modules/FilesystemModule.cpp átírása pushEvent alapúra.
- main.cpp frissítése: A FilesystemModule visszakommentelése és indítása.
- Makefile: A forrásfájlok listájának bővítése.

