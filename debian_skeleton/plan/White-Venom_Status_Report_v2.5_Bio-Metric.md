# 🐍 White-Venom Framework - Telemetria és Ütemezési Jelentés v2.5

## 🎯 Stratégiai Áttekintés
A rendszer a klasszikus szűrés helyett **folyamatos szabályozást** és **determinista útválasztást** alkalmaz. A biztonsági döntések alapja nem a tartalom, hanem a rendszer saját belső időreferenciája (**Time-Cube**) és anyagcseréje (**SystemMetabolism**).

---

## 🧬 Megvalósított Specifikációk

### 1. Time-Cube Profiling (Idő-alapú Önvédelem)
* **Koncepció**: Belső, hardverfüggetlen időszegmensek (Tick-alapú költség), amelyek a 25 hardening modul természetes futási profilján alapulnak.
* **Működés**: Minden modul rendelkezik egy `ModuleTimeProfile`-al, amely meghatározza az elvárt futási költséget (`expectedCostTicks`) és a toleranciasávot.
* **Rejtőzködés**: A referenciaidő kívülről nem rekonstruálható, így a támadó nem tudja megfigyelni a döntési pontokat.

### 2. System Metabolism (Rendszer-anyagcsere)
* **Dinamikus Skálázás**: A `loadFactor` (aktuális tick / referencia tick) figyelembevételével a Time-Cube határai rugalmasan tágulnak terhelés alatt.
* **LoadFactor**: Ha > 1.0, a rendszer érzékeli a lassulást, és több időt engedélyez a moduloknak, elkerülve a téves riasztásokat.

### 3. NullScheduler & "Ventiláció"
* **Kannibál Scheduler**: Egy speciális worker, amely azonnal elnyeli a profilból kilépő eseményeket anélkül, hogy erőforrást pazarolna vagy visszajelzést adna.
* **Biztonsági Előny**: Megakadályozza a DoS felerősítést és a visszacsatolás alapú próbálkozásokat (nincs hibaüzenet, csak elnyelés).
* **Döntési Logika**: Ha a stream elvárás (pl. TEXT vs BINARY) sérül, vagy a ráta túl magas, az esemény automatikusan a NullScheduler-re irányítódik.

---

## 📊 Telemetria Állapot
* **Atomi Monitoring**: A `BusTelemetry` valós időben követi az elfogadott, eldobott és "null-routed" (elnyelt) eseményeket.
* **Snapshot**: A rendszer pillanatképeket készít, amelyek tartalmazzák a Time-Cube sértések számát és a pillanatnyi anyagcsere-szorzót.
* **Profilváltás**: Támogatja a `NORMAL` (emberi léptékű) és `HIGH` (emelt készültségű) módokat; utóbbiból nincs automatikus visszatérés a biztonság érdekében.

---

## 🛠️ Következtetés
A White-Venom v2.5 már nem csak egy szoftver, hanem egy "csendes, unalmas és hatékony" immunrendszer, amely a rossz bemenetet egyszerűen kiszellőzteti a rendszerből.
