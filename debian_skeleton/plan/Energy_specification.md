###​White Venom Technical Spec v3.0 (RxCPP / Two-Branch)
-​1. Koncepció: Silent Ventilation

​A rendszer alapja nem a detekció, hanem az elvárás (Expectation). Ami nem illik a profilba, azt nem elemezzük a "mentes" ágon, hanem egyszerűen kiszellőztetjük a NULL Scheduler-en keresztül. No feedback, no log, no overhead.
​2. Fejlesztési Ágak (The Split)
​A. STABLE (Mentes)
​RxCPP Pipeline: Source -> StreamProbe -> Filter -> NullScheduler
​Funkció: Tiszta hálózati védelem. Ha az entrópia vagy a típus (BINARY/UNKNOWN) nem stimmel, az adat megy a levesbe.
​Cél: Stabilitás és integritás. Az ügyfél ezt kapja a pénzéért.
​B. PRIVATE (Bányász)
​RxCPP Pipeline: Source -> StreamProbe -> Map (XOR-Fusion) -> Harvester -> NullScheduler
​Funkció: A NullScheduler előtt egy láthatatlan hook kinyeri a bináris zajt.
​Bányászat: XOR-alapú entrópia-gyűjtés. A "majmok" zaja adja a nyersanyagot.
​Titkosítás: A kinyert zaj hajtja a belső kulcsforgatást, amit a Time-Cube (25 hardening modul ritmusa) szinkronizál.
​3. Stream Taxonomy (Probe-alapú döntés)
​TEXT / JSON: < 5.8 entrópia -> Mehet a feldolgozóba.
​BINARY / NOISE: > 5.8 - 6.8 entrópia -> Mehet a ventilációba (és a privát ágon a bányászba).
​4. Time-Cube Integritás
​A rendszer saját fiziológiája (IO terhelés / modul futási idő) az időreferencia.
​Kívülről nem mérhető, nem jósolható. Ez a titkosításod lelke.
