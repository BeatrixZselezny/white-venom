# White-Venom Evolution Log
**Dátum:** 2026. február 16.
**Mérföldkő:** v2.1-stable (The Clean Snake)

## ✅ Implementált Változások

### 1. Zombi-szál (HUP-Bug) felszámolása
- **Probléma:** A `venom_engine` leállításkor (SIGINT) nem zárta le az aszinkron szálakat, így a bináris "beragadt" a memóriába.
- **Megoldás:** `engine_lifetime` (composite_subscription) bevezetése. 
- **Eredmény:** Azonnali, tiszta leállás (Graceful Shutdown) minden CTRL+C-nél.

### 2. SocketProbe (Port 8888)
- **Funkció:** Új bemeneti szonda a Zero-Trust forgalomhoz.
- **Védelem:** Beépített 10:1 arányú mintavételezés (sampling), ha a `loadFactor` meghaladja a 2.0-át.

### 3. VenomBus Reactive Pipeline
- **Ablakozás:** 200ms-os `window_with_time` ablakok bevezetése a `VenomBus.hpp`-ban.
- **Metabolizmus:** A rendszer automatikusan eldobja a redundáns eseményeket, ha az entrópia küszöbérték fölé ugrik ($6.8 \times (loadFactor + 0.11)$).

### 4. Hardening Status
- **Build:** Makefile frissítve `-fstack-protector-all` és `-Wl,-z,relro,-z,now` flag-ekkel.
- **Bináris:** Statikusan linkelt RxCpp és Zero-Trust engine.
