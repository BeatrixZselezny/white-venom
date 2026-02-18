# 🐍 Project White-Venom: Hydra Interface Design (v3.0-alpha)

**Státusz:** Tervezési fázis (Draft)
**Cél:** A White-Venom kiterjesztése publikus interfészekre (eth0, wlan0, stb.) intelligens IP-alapú szűréssel és adaptív védelemmel.

## 1. Architektúra: "A Hydra Fejei"
A Hydra nem egyetlen bemeneti pont, hanem egy **Multi-Ingress Driver**, amely képes párhuzamosan figyelni több hálózati interfészt.

### 1.1. Ingress Agnosztika
A `SocketProbe` örökli a `HydraBase` osztályt, amely lehetővé teszi:
- **Wildcard Binding:** `0.0.0.0` (minden interfész) vagy specifikus publikus IP.
- **Port Hopping (Opcionális):** A figyelő port dinamikus változtatása a `loadFactor` függvényében.

## 2. Reaktív Védelmi Lánc (The Hydra Pipeline)

A beérkező csomagoknak egy többszintű "szűrő-vízesésen" kell átmenniük:

### 2.1. L0: IP-Reputation & Blacklist (A Gyorsvágó)
- **Funkció:** Azonnali eldobás, ha az IP szerepel a helyi feketelistán.
- **Technológia:** `std::unordered_set` (O(1) keresés) a reaktív lánc elején.

### 2.2. L1: Adaptive Rate Limiting (Az "IP-Fojtó")
- **Koncepció:** IP-alapú ablakozás.
- **Szabály:** Ha egy IP > 100 pkt/sec sebességgel lő, a Hydra automatikusan "lefejezi" az adott forgalmat (irány a Null-Sink/WC).
- **Logika:** `window_with_time` + `group_by(e.source_ip)`.

### 2.3. L2: Entropy-Based Triage (A "Kígyó Harapása")
- **Funkció:** Shannon-entrópia számítás.
- **Dinamikus küszöb:** $Threshold = 6.8 \times (1 / (Load + 0.1))$.
- **Eredmény:** A bináris szemét (exploit kísérletek) a WC-be kerül, a tiszta TEXT/JSON a Cortexbe.

## 3. Adatstruktúra: `HydraEvent`
A meglévő `VentEvent` kiterjesztése metaadatokkal:
```cpp
struct HydraEvent : public VentEvent {
    std::string source_ip;    // Támadó IP-je
    uint16_t interface_id;    // Melyik interfészen jött (eth0, eth1...)
    double risk_score;        // Dinamikusan számolt kockázati érték
};
