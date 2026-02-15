# 🐍 White-Venom: Master Context Package (v2.1-stable)

## 1. Projekt Architektúra & Cél
* **Név:** White-Venom
* **Cél:** Debian bootstrap hardening és Zero-Trust rendszerfelügyelet.
* **Nyelv:** C++ (RxCpp reaktív motorral).
* **Fő komponensek:** Kettős belső busz (Cortex & NullScheduler).

## 2. Könyvtárstruktúra Manifest
* **`src/core` & `include/core`**: A rendszer szíve (Cortex, Orchestrator, VenomBus).
* **`src/telemetry`**: A "szenzorok" és a `loadFactor` számítás helye.
* **`include/modules`**: A 25 biztonsági modul definíciói.
* **`include/rxcpp/`**: Egyedi reaktív operátorok és a NullScheduler.
* **`debian_skeleton`**: Audit szabályok, firewall és hardening alapok.

## 3. Szigorú Fejlesztési Szabályok (Protocol Zero)
* **Nincs Copy-Paste:** Minden javítás vagy változtatás előtt a felhasználó átadja az aktuális állományt, az AI pedig a **teljes állományt** adja vissza a módosításokkal együtt.
* **Integritás-védelem:** Tilos az önálló "kódszépítés", törölgetés vagy refaktorálás a felhasználó kifejezett kérése nélkül. 
* **Párhuzamos Modulkezelés:** Új modul létrehozásakor kötelező a `.cpp` és `.hpp` páros (kivétel, ha technológiailag csak header-only megoldás indokolt).
* **Karakterhelyesség:** A kódból egyetlen betű, deklaráció vagy include sem hiányozhat, amit a felhasználó előzetesen nem hagyott jóvá.
* **Include-Védelem:** Soha ne távolíts el `#include "core/..."` vagy `#include "telemetry/..."` sorokat, mert a busz-regisztráció megszakadhat.

## 4. Technikai Paraméterek
* **Metabolism-Aware:** Szűrési képlet: $Threshold_{dynamic} = 6.8 \times (loadFactor + 0.11)$.
* **Null-Routing:** Magas entrópiájú adatok a `NullScheduler`-be kerülnek.
* **Stabil Verzió:** v2i.1-adaptive.

## 5. Ismert Hibák & Roadmap
* **Shutdown Hiba:** A worker szálak bennragadnak szignál esetén (Megoldás: `unsubscribe()`).
* **Következő lépés:** `feature/clean-shutdown-dev` branch kezelése.

## Project map

white-venom/
 ├── context/                       # AI Context Package-ek helye
 ├── debian_skeleton/               # A projekt C++ és hardening bázisa
 │   ├── 00_install.sh              # Telepítő ruton
 │   ├── 01-25_*.sh                 # Hardening modulok (DNS, sysctl, AppArmor, stb.)
 │   ├── include/                   # Header állományok (.hpp)
 │   │   ├── core/                  # Alapvető motor-logika
 │   │   │   ├── NullScheduler.hpp  # Az adat-nyelő (Black Hole)
 │   │   │   ├── VenomBus.hpp       # Az RxCpp alapú üzenetbusz
 │   │   │   ├── StreamProbe.hpp    # Entrópia és folyamat-analízis
 │   │   │   └── SafeExecutor.hpp   # Fork/execv alapú biztonságos futtatás
 │   │   ├── modules/               # Magas szintű modulok (Filesystem, InitSecurity)
 │   │   ├── telemetry/             # BusTelemetry, Snapshot típusok
 │   │   ├── rxcpp/                 # Egyedi/beágyazott RxCpp könyvtár és operátorok
 │   │   ├── utils/                 # HardeningUtils, ConfigTemplates, Policy-k
 │   │   └── TimeCubeTypes.hpp      # Speciális típusdefiníciók
 │   ├── src/                       # Forrásfájlok (.cpp)
 │   │   ├── core/                  # Busz, Scheduler és Probe implementációk
 │   │   ├── modules/               # C++ modulok üzleti logikája
 │   │   ├── telemetry/             # Adatgyűjtés és loadFactor számítás
 │   │   ├── utils/                 # Policy registry és inicializálók
 │   │   └── main.cpp               # Belépési pont (Cortex életciklus)
 │   ├── audit/                     # Auditd szabályrendszerek
 │   ├── firewall/                  # Netfilter/IP6Tables konfigurációk
 │   └── Makefile                   # Statikus, hardened fordítási szabályok
 ├── backup/                        # Biztonsági mentések
 ├── docs/                          # DECISIONS és technikai leírások
 ├── plan/                          # Ütemtervek és fázis-leírások
 └── scripts/                       # Kiegészítő teszt szkriptek (lo_test, apt_conf)



 ## ⚠️ White-Venom Fejlesztési Alapvetés: A "Bölcső" Elv

A projekt fejlődése során a hangsúly és a megvalósítás eltolódott a kezdeti tervektől a modern, reaktív implementáció irányába:

* **A "Bölcső" (debian_skeleton/*.sh):** A Bash-alapú scriptek a projekt kezdeti tervezési fázisát reprezentálják. Ezek nem aktív végrehajtó elemek, hanem a "Blueprint" (tervrajz) szerepét töltik be.
* **C++ Motor (src/include):** A White-Venom egyetlen aktív entitása és "idegrendszere". Minden hardening logika, amely a Bash scriptekben megfogalmazódott, itt kerül natív, reaktív (RxCpp) megvalósításra.
* **Implementációs Irány:** A fejlesztés során a Bash-ben rögzített biztonsági célokat ("miért") fordítjuk le C++ nyelvre ("hogyan"), szigorúan követve a Zero-Trust és a Metabolism-Aware architektúrát.
* **Kizárólagosság:** A futó rendszerben a C++ bináris felelős minden műveletért; a Bash scriptek csak elméleti referenciaként léteznek a forráskódban.



## Projekt állományok értelmezései


### 🛠️ Jelentés: Build System & Hardening (Makefile)
- include/src: core
A White-Venom build folyamata a **C++20** szabványra épül, és szigorú, alacsony szintű biztonsági védelmet kényszerít ki a bináris szinten.

#### [cite_start]1. Fordítási Biztonság (Hardened CXXFLAGS) [cite: 1]
* [cite_start]**Stack Védelem**: A `-fstack-protector-strong` és `-fstack-clash-protection` használatával a rendszer aktívan védekezik a puffertúlcsordulásos és stack-clash alapú támadások ellen[cite: 1].
* [cite_start]**Source Fortification**: A `-D_FORTIFY_SOURCE=2` bekapcsolásával a fordító és a glibc további runtime ellenőrzéseket végez a memóriakezelő függvényeknél[cite: 1].
* [cite_start]**Szabvány és Optimalizáció**: A rendszer a `-std=c++20` szabványt használja `-O2` optimalizációs szint mellett, `-pthread` támogatással az aszinkronitás érdekében[cite: 1].

#### [cite_start]2. Linkelési Stratégia (Hardened LDFLAGS) [cite: 1]
* [cite_start]**Statikus Linkelés**: A `-static` flag biztosítja, hogy a `venom_engine` minden függőséget (pl. RxCpp, standard libek) tartalmazzon, kiküszöbölve a "Shared Library Hijacking" kockázatát[cite: 1].
* [cite_start]**Full RELRO**: A `-Wl,-z,relro,-z,now` kapcsolók a bináris betöltése után azonnal írásvédetté teszik a GOT (Global Offset Table) táblát, megakadályozva az eltereléses támadásokat[cite: 1].

#### [cite_start]3. Moduláris Felépítés [cite: 2, 3]
* [cite_start]**Forráskezelés**: A build rendszer elkülönítve kezeli a `core`, `telemetry` és `modules` könyvtárakat, dedikált fordítási szabályokkal minden alrendszerhez[cite: 2, 3].
* [cite_start]**Célbináris**: A végtermék a `bin/venom_engine`, amely a statikus linkelés miatt egyetlen, hordozható és önmagában is védett fájl[cite: 1].



### 🚀 Jelentés: Rendszer Életciklus és Belépési Pont (main.cpp)

A `main.cpp` a White-Venom motorjának központi vezérlője, amely koordinálja a modulok inicializálását, az aszinkron busz indítását és a biztonsági profilok szerinti futást.

#### 1. Életciklus-kezelés és Reaktív Kontextus
* **Lifetime Management**: A rendszer az `rxcpp::composite_subscription lifetime` objektumot használja a reaktív láncok globális kezelésére. Ez biztosítja, hogy minden feliratkozás (subscription) egyetlen ponton keresztül leállítható legyen.
* **Szignálkezelés**: A `SIGINT` (CTRL+C) elkapása egy atomi `keepRunning` flag-en keresztül történik, amely lehetővé teszi a ciklusból való szabályos kilépést.
* **Felszabadítási Sorrend**: A leállási fázisban a `lifetime.unsubscribe()` hívás hivatott leállítani a reaktív folyamatokat, mielőtt a `scheduler.stop()` leállítaná az ütemezőt.

#### 2. Operációs Módok
* **Service Mode (`--service`)**: Folyamatos figyelési üzemmód. Elindítja a `FilesystemModule` monitorozását, és valós idejű telemetriát szolgáltat a `VenomBus` adataiból (sor hossza, összesített események, elfogadott események, aktuális biztonsági profil).
* **One-Shot Mode**: Egyszeri audit futtatás. Elvégzi a statikus ellenőrzéseket, beküldi az eseményt a buszra, majd szabályosan leáll.

#### 3. Moduláris Sorrendiség (Boot Sequence)
1. **InitSecurityModule**: Statikus, blokkoló végrehajtás (`execute()`), amely elvégzi a rendszer kezdeti sterilizálását (a "bölcsőben" leírtak alapján).
2. **VenomBus & Scheduler**: Az infrastruktúra felállítása és az aszinkronitás aktiválása.
3. **FilesystemModule**: A fájlrendszer auditálása, majd igény szerint a reaktív monitorozás megkezdése.

#### 4. Diagnózis a Context Package számára
* **Shutdown Probléma**: Bár a `lifetime.unsubscribe()` meghívásra kerül, az RxCpp belső thread-pooljai (schedulerek) néha blokkolódnak, ha az eseményhurok várakozik. Ez okozza a jelentésben említett "zombi szálak" jelenséget, amit a jövőben a `Scheduler.cpp` és `VenomBus.hpp` finomhangolásával kell orvosolni.


### 🧠 Jelentés: Core Idegrendszer - VenomBus (v2i.1-adaptive)

A `VenomBus` a White-Venom központi adat-autópályája, amely a nyers események (VentEvent) osztályozásáért és a validált parancsok (CortexCommand) irányításáért felelős.

#### 1. Kettős Busz Architektúra (Twin Buses)
* **VentBus**: Alacsony szintű reaktív subject a beérkező nyers adatok számára.
* **CortexBus**: Magas szintű subject a validált, végrehajtható biztonsági parancsok számára.
* **Infrastruktúra**: A busz integrált `BusTelemetry`-vel és `TimeCubeBaseline` időzítéssel rendelkezik az adaptív működéshez.

#### 2. Adaptív Pipeline és Metabolizmus (Implementáció)
* **Szakaszolás (Windowing)**: A rendszer 200ms-os időablakokban vagy 10 eseményenként kötegeli az adatokat a CPU-hatékonyság érdekében.
* **Dinamikus Küszöbkezelés**: A szűrési algoritmus a `telemetry.get_metabolism()` adatai alapján számítja ki az aktuális biztonsági szintet.
  * **Képlet**: $Threshold_{dynamic} = 6.8 \times (1.0 / (loadFactor + 0.1))$.
* **Zero-Trust Szűrés**: Minden esemény átesik a `StreamProbe::detectZeroTrust` és `calculateEntropy` vizsgálaton.

#### 3. Irányítási Logika (Routing)
* **Normal Path**: A validált események a `CortexScheduler`-re kerülnek feldolgozásra.
* **Null-Routing**: A gyanús vagy bináris (DataType::BINARY) adatokat a `NullScheduler` nyeli el, növelve a `null_routed_events` számlálót.
* **Aszinkronitás**: Az események irányítása a `rxcpp::observe_on_one_worker` segítségével történik, elkerülve a fő szál blokkolását.

#### 4. Technikai rögzítések a Context Package számára
* **Type-Safe Fix**: A `group_by` operátor után explicit `rxcpp::grouped_observable<std::string, VentEvent>` típust használunk a stabilitás érdekében.
* **Lifetime Hook**: A belső reaktív láncok a fő `lifetime` előfizetésre vannak felfűzve, biztosítva a központi leállíthatóságot.
* **Diagnosztika**: A `getTelemetrySnapshot()` metódus pillanatképet ad a várólista mélységéről és az események státuszáról.



### 🌑 Jelentés: Core Végpont - NullScheduler

A `NullScheduler` a White-Venom architektúra "fekete lyuka". Feladata a gyanús, magas entrópiájú vagy károsnak minősített események csendes elnyelése anélkül, hogy a rendszer erőforrásait (CPU, I/O, Naplózás) szükségtelenül terhelné.

#### 1. Működési Mechanizmus (Kannibál Scheduler)
* [cite_start]**Worker Implementáció**: A `create_worker()` metódus egy `rxcpp::identity_one_worker`-t ad vissza, amely a feladatokat azonnal, ütemezési overhead nélkül kezeli[cite: 3, 2].
* [cite_start]**Szálkezelés**: A `make_current_thread()` használatával a művelet nem vált szálat, így minimalizálva a kontextusváltási költséget az elnyelés során[cite: 2].

#### 2. "Ventiláció" és Adat-abszorpció
* [cite_start]**Absorb Funkció**: A `absorb` sablonfüggvény befogadja az adatfolyamot, de azonnal megszakítja a reaktív láncot[cite: 2].
* [cite_start]**DoS Védelem**: A tervezési elv szerint az elnyelt eseményekről nem készül egyenkénti naplózás, megakadályozva ezzel a log-flood alapú DoS támadásokat[cite: 3].
* [cite_start]**Metrika Kezelés**: Bár az adat elvész, a rendszer belső, névtelen metrikákat frissít (pl. a `VenomBus`-ban látható `null_routed_events` számláló), hogy a telemetria lássa az elnyelt forgalom mértékét[cite: 2, 3].

#### 3. Stratégiai Jelentőség
* [cite_start]**Csendes Védelem**: Nem küld hibaüzenetet vagy riasztást a forrásnak, így a támadó nem kap visszajelzést a szűrés sikerességéről[cite: 2].
* **Rendszer Stabilitás**: Biztosítja, hogy a `CortexScheduler` (az "agy") csak tiszta, validált adatokkal foglalkozzon, fenntartva a reaktív válaszkészséget magas terhelés mellett is.

#### 4. Diagnózis a Context Package számára
* [cite_start]**Statikus Jelleg**: A logika nagy része a `NullScheduler.hpp`-ban található a template-alapú abszorpció miatt; a `.cpp` fájl csak a névtér konzisztenciáját szolgálja[cite: 1, 2].


### 👁️ Jelentés: Core Szonda - StreamProbe

A `StreamProbe` a White-Venom Zero-Trust architektúrájának első védelmi vonala. Feladata az adatfolyamok gyors, alacsony erőforrás-igényű osztályozása és a potenciálisan veszélyes (magas entrópiájú vagy bináris) forgalom azonosítása.

#### 1. Adat-osztályozási kategóriák (DataType)
A szonda öt különböző állapotot képes megkülönböztetni:
* **TEXT**: Emberi léptékű szöveg vagy parancsok.
* **JSON**: Strukturált konfigurációs adatok.
* **METRIC**: Számszerűsített telemetriai adatok.
* **BINARY**: Ismeretlen eredetű, potenciálisan veszélyes vagy titkosított adathalmazok.
* **UNKNOWN**: Eldönthetetlen vagy sérült adatfolyam.

#### 2. Shannon-entrópia analízis
* **Működés**: A `calculateEntropy` metódus kiszámítja az adat statisztikai bizonytalanságát. Minél közelebb van az érték a 8.0-hoz (8 bites adatok esetén), annál valószínűbb a tömörített vagy titkosított tartalom.
* **Dinamikus Küszöb**: A `detectZeroTrust` metódus a biztonsági profil alapján (`SecurityProfile`) vált a szigorúsági szintek között:
    * **NORMAL**: 6.8-as entrópiás küszöbérték.
    * **HIGH**: Szigorított, 5.8-as küszöbérték.

#### 3. Zero-Trust Detektálási Logika
* **Bináris vizsgálat**: A szonda ellenőrzi a nem nyomtatható karakterek arányát. Ha ez meghaladja a 30%-ot, az adatot azonnal `BINARY` típusnak minősíti.
* **Formátum felismerés**: Egyszerűsített, gyors kereséssel (JSON karakterek keresése) dönti el, hogy strukturált adatról van-e szó, elkerülve a nehéz parser-ek (Deep Parsing) használatát.
* **Integráció**: A detektált típus határozza meg a `VenomBus`-ban, hogy az esemény a normál feldolgozó ágra vagy a `NullScheduler` általi elnyelésre kerül-e.

#### 4. Diagnózis a Context Package számára
* **Könnyűsúlyú kialakítás**: A szonda nem allokál nehéz objektumokat, így alkalmas nagy sebességű stream-ek valós idejű elemzésére.
* **Profil-függőség**: A döntési mechanizmus közvetlenül támaszkodik a `TimeCubeTypes.hpp` állományban definiált biztonsági profilokra.


### 🛡️ Jelentés: Core Jogosultságkezelés - PrivilegeContext & Decision

A Privilege alrendszer felelős a White-Venom modulok jogosultsági igényeinek definiálásáért és összesítéséért. Ez biztosítja, hogy a rendszer csak a minimálisan szükséges privilégiumokat aktiválja az adott feladathoz.

#### 1. Jogosultsági Szintek (PrivilegeLevel)
A rendszer három jól elkülöníthető szintet ismer:
* [cite_start]**None**: Nincs speciális jogosultság igény. [cite: 1]
* [cite_start]**UserNS**: Felhasználói névtér (User Namespace) szintű izoláció. [cite: 1]
* [cite_start]**Root**: Teljes rendszerszintű adminisztratív hozzáférés. [cite: 1]

#### 2. Granuláris Képességek (PrivilegeContext)
A `PrivilegeContext` struktúra bináris kapcsolókkal határozza meg a specifikus műveleti igényeket:
* [cite_start]**needs_mount_ns**: Igény a csatolási névtér manipulálására. [cite: 1]
* [cite_start]**needs_sysctl**: Kernel paraméterek (sysctl) módosításának igénye. [cite: 1]
* [cite_start]**needs_fs_write**: Írási jogosultság a fájlrendszer védett részeihez. [cite: 1]
* [cite_start]**needs_net_admin**: Hálózati konfigurációs és adminisztrációs jogkör. [cite: 1]
* [cite_start]**reason**: Kötelező szöveges indoklás a jogosultság igényléséhez (audit célokra). [cite: 1]

#### 3. Összesítési Logika (mergeContexts)
A `PrivilegeDecision.cpp`-ben található `mergeContexts` függvény felelős több modul igényeinek biztonságos összefésüléséért:
* [cite_start]**Level Escalation**: Mindig a legmagasabb kért `PrivilegeLevel`-t tekinti irányadónak a listából. [cite: 2]
* [cite_start]**Capability ORing**: A specifikus igényeket (mount, sysctl, net, fs) logikai VAGY kapcsolattal összesíti. [cite: 2] [cite_start]Ha bármelyik modulnak szüksége van egy képességre, az a végleges kontextusban aktív lesz. [cite: 2]

#### 4. Diagnózis a Context Package számára
* **Zero-Trust Integráció**: Ez a komponens biztosítja, hogy a `SafeExecutor` pontosan tudja, milyen "szűkített" környezetet kell létrehoznia az adott művelet végrehajtásához.
* **Biztonsági audit**: A `reason` mező megléte kényszeríti a fejlesztőt, hogy dokumentálja a privilégium-szint emelésének okát a kódban.


### 🔗 Jelentés: Privilege Interfész - PrivilegeDecision.hpp

A `PrivilegeDecision.hpp` biztosítja az absztrakciós réteget a jogosultságok összesítéséhez, lehetővé téve, hogy a rendszer különböző moduljai egységesen kezeljék a privilégium-igényeket.

#### 1. Struktúra és Definíció
* **Interfész**: Definiálja a `mergeContexts` függvény szignatúráját, amely bemenetként egy `PrivilegeContext` vektorát várja.
* **Header-only jelleg**: Megjegyzendő, hogy a `PrivilegeContext` jelenleg csak header állományként létezik, mivel tisztán adatstruktúrákat tartalmaz, ami optimális a fordítási idő és az egyszerűség szempontjából.

#### 2. Szerep a Fordítási Egységekben
* **Függőség-kezelés**: Ez a header teszi lehetővé a `SafeExecutor` és más kontroll-modulok számára, hogy anélkül végezzenek jogosultság-összesítést, hogy ismerniük kellene az implementáció részleteit.
* **Típusbiztonság**: A `Venom::Core` névtér használatával garantálja, hogy a jogosultsági döntések ne keveredjenek más rendszerelemek logikájával.


### 🚪 Jelentés: Core Biztonsági Kapu - SafeExecutor

A `SafeExecutor` a White-Venom egyik legkritikusabb biztonsági komponense. Feladata a külső binárisok futtatása úgynevezett "Prepared Statement" logika alapján, megakadályozva ezzel a parancsinjekciós támadásokat.

#### 1. "Prepared Statement" Logika
* [cite_start]**Szétválasztás**: A rendszer szigorúan külön kezeli a bináris útvonalát és a hozzá tartozó argumentumokat egy `std::vector<std::string>` formájában[cite: 3].
* [cite_start]**Shell-mentesség**: Nem használ shell-interpretációt (mint a `system()` vagy `popen()`), így a speciális karakterek (pl. `;`, `&`, `|`) nem tudják manipulálni a végrehajtást[cite: 3].

#### 2. Implementációs Biztonság (fork/execv)
* [cite_start]**Elkülönített folyamat**: A `fork()` hívással a rendszer egy másolatot hoz létre, így a fő motor (`venom_engine`) memóriaterülete védett marad a végrehajtott bináris hibái vagy összeomlása esetén[cite: 2].
* [cite_start]**Execv Mechanizmus**: Az `execv(binary.c_str(), c_args.data())` hívás közvetlenül az operációs rendszernek adja át a vezérlést, garantálva, hogy pontosan az a fájl indul el, amit a kód meghatározott[cite: 2].
* [cite_start]**Hibakezelés**: Ha a bináris nem található vagy nem futtatható, a gyerek folyamat az atomi `_exit(127)` hívással fejeződik be, elkerülve a standard C++ cleanup folyamatok (pl. destruktorok) kétszeri lefutását a szülő és a gyerek ágon[cite: 2].

#### 3. Szülő-Gyerek Szinkronizáció
* [cite_start]**Visszatérési érték**: A szülő folyamat a `waitpid` segítségével megvárja a végrehajtást, és csak akkor ad vissza `true` értéket, ha a bináris szabályosan (`WIFEXITED`) és hiba nélkül (`WEXITSTATUS == 0`) állt le[cite: 2].

#### 4. Diagnózis a Context Package számára
* **Stratégiai szerep**: Ez a modul a kapocs a C++ motor és a rendszer egyéb eszközei között.
* [cite_start]**Integráció**: A `SafeExecutor` közvetlenül támaszkodik az `ExecPolicyRegistry`-re a futtatási irányelvek betartásához[cite: 3].


### ⚙️ Jelentés: Core Ütemező - Scheduler

A `Scheduler` a White-Venom motorjának aszinkron koordinátora. Feladata a három elkülönített végrehajtási domén (Vent, Cortex, Null) menedzselése és a reaktív láncok életciklusának felügyelete.

#### 1. Izolált Végrehajtási Domének
A rendszer három különböző stratégiát alkalmaz a feladatok ütemezésére:
* **Vent Domén (`make_event_loop`)**: Párhuzamos worker pool. Feladata a nagy tömegű, beérkező nyers események (telemetria, naplók) fogadása és előszűrése anélkül, hogy blokkolná a rendszert.
* **Cortex Domén (`make_new_thread`)**: Egyetlen, dedikált szál a biztonsági logika futtatásához. Ez garantálja a determinisztikus sorrendiséget: a döntések nem akadhatnak össze, és nem versenghetnek egymással (race condition megelőzés).
* **Null Domén (`make_current_thread`)**: A rendszer "nyelője" (sink). Az aktuális szálon hajtja végre a feladatot (ami a `NullScheduler` esetében az azonnali elnyelést jelenti), így nem igényel extra kontextusváltást vagy memória-allokációt.

#### 2. Életciklus és Biztonság
* **Determinisztikus Leállítás**: A `stop()` metódus a `lifetime.unsubscribe()` hívással kényszeríti a reaktív láncok lezárását, mielőtt a szálakat elengedné.
* **Hibajavítás (Type-Safe Fix)**: Az állomány tartalmazza a korábban diagnosztizált `getNullScheduler` tagfüggvényt, így a `VenomBus` már képes a gyanús forgalmat a megfelelő ütemezőhöz irányítani.

#### 3. Diagnózis a Context Package számára
* **Erőforrás Gazdálkodás**: A `Scheduler` biztosítja, hogy a CPU-intenzív feladatok (Vent) ne zavarják a kritikus döntéshozatalt (Cortex).
* **Thread-Safety**: Az `std::atomic<bool> running` flag és az RxCpp kompozit feliratkozásai garantálják a szálbiztos működést a motor indítása és leállítása során.


## include/src: modules

### 📂 Jelentés: Végrehajtó Modul - FilesystemModule

A `FilesystemModule` felelős a kritikus rendszerfájlok és könyvtárak integritásának védelméért. Két üzemmódot támogat: egy egyszeri statikus auditot és egy folyamatos, eseményvezérelt monitorozást.

#### 1. Statikus Audit (Scan Mode)
* [cite_start]**Policy alapú ellenőrzés**: A modul előre definiált szabályrendszert (`FilesystemPathPolicy`) követ olyan kritikus útvonalakra, mint az `/etc`, `/var`, `/tmp` és `/home`.
* [cite_start]**Integritás vizsgálat**: Ellenőrzi az útvonal létezését, típusát (könyvtár-e), és a jogosultságokat (pl. tiltott world-writable állapot).
* [cite_start]**Eseményközlés**: Minden audit-eltérés (pl. `MISSING_PATH`, `WORLD_WRITABLE`) közvetlenül a `VenomBus` reaktív ágába kerül `FS_AUDIT` forrásmegjelöléssel.

#### 2. Valós idejű Monitorozás (Watch Mode)
* [cite_start]**Inotify Integráció**: A Linux kernel `inotify` API-ját használja a fájlrendszeri események (létrehozás, törlés, módosítás) alacsony késleltetésű detektálására.
* [cite_start]**Aszinkronitás**: A monitorozás egy elkülönített szálon (`monitorLoop`) fut, így nem blokkolja a fő motor működését.
* [cite_start]**Szelektív Figyelés**: Csak a `watchRealTime` flaggel megjelölt útvonalakat (pl. `/etc`, `/tmp`) figyeli aktívan.

#### 3. Reaktív Kapcsolat (Metabolism-Awareness)
* [cite_start]**Bus Push**: Az észlelt események (pl. `CREATED: passwd`) a `bus.pushEvent` segítségével bekerülnek a `VenomBus`-ba.
* [cite_start]**Zero-Trust Input**: Ez a modul szolgáltatja a nyers adatokat a `StreamProbe` számára, amely később eldönti, hogy az esemény gyanús-e vagy elfogadható.

#### 4. Diagnózis a Context Package számára
* [cite_start]**Biztonságos Leállítás**: A modul atomi `keepMonitoring` flaget és a fájlleíró (`inotifyFd`) lezárását használja a tiszta leálláshoz a `stopMonitoring` hívásakor.
* [cite_start]**Erőforrás Kezelés**: A `select()` hívás alkalmazása 1 másodperces timeouttal biztosítja, hogy a monitorozó szál reagáljon a leállítási kérelemre, elkerülve a zombi folyamatok kialakulását.


### 🛡️ Jelentés: Végrehajtó Modul - InitSecurityModule

Az `InitSecurityModule` a White-Venom motor "nulladik" fázisa. [cite_start]Feladata a legkritikusabb biztonsági alapozás elvégzése a rendszer indulásakor, mielőtt a reaktív busz és az ütemező aktívvá válna[cite: 1, 3].

#### 1. Architektúrális Váltás (Standalone Design)
* **Interfész-mentesség**: A modul már nem örököl az `IBusModule` interfészből, ami biztosítja a minimális függőséget és a determinisztikus lefutást a korai boot fázisban.
* [cite_start]**Statikus Végrehajtás**: Az `execute()` metódus blokkoló módon fut le a `main.cpp`-ben, garantálva, hogy a biztonsági politikák érvénybe lépnek, mielőtt bármilyen külső adat beérkezne[cite: 3].

#### 2. Bootstrap Mechanizmus
* **Szinkron Alapozás**: A modul jelenleg egy 20ms-os ablakot definiál, amely a jövőben a `Time-Cube` mérések kalibrációjához és az irányelvek betöltéséhez szolgál.
* **Irányelv Alkalmazás**: Itt történik a rendszerszintű hardening politikák kezdeti beállítása a tervezési fázisban meghatározottak szerint.

#### 3. Diagnózis a Context Package számára
* [cite_start]**Kritikus Sorrendiség**: Ez az egyetlen modul, amelynek be kell fejeződnie a `VenomBus` indítása előtt[cite: 3].
* **Integrációs Pont**: A kód előkészített hellyel rendelkezik az `ExecPolicyRegistry` számára.

---

### 📝 Stratégiai Megjegyzés (Implementációs Döntés)

**Fontos megjegyzés a modul felépítéséhez:**
Az `InitSecurityModule` tudatosan lett leválasztva a reaktív buszrendszerről. Ez a döntés azt a célt szolgálja, hogy a biztonsági "alapkőletétel" ne aszinkron módon, hanem kényszerített, szinkron sorrendben történjen meg. Így elkerülhető az a versenyhelyzet (race condition), ahol egy reaktív esemény már feldolgozásra kerülne azelőtt, hogy a rendszerszintű védelmi vonalak (pl. `ExecPolicy`) felálltak volna. Ez a modul a "bizalom alapja", amire a későbbi Zero-Trust folyamatok épülnek.


### 📦 Jelentés: Külső Függőség - RxCpp (Reactive Extensions for C++)

Az `include/rxcpp` könyvtár tartalmazza a projekt reaktív motorját. Ez egy harmadik féltől származó (header-only) könyvtár, amely a White-Venom aszinkron eseménykezelésének matematikai alapjait adja.

#### 1. Bejárási Stratégia (AI Policy)
* **Hatókör**: Az `rxcpp` könyvtár belső állományait (pl. `rx-operators.hpp`, `rx-observable.hpp`) **nem járjuk be és nem módosítjuk**.
* **Indoklás**: Ez egy standardizált külső függőség. A mi feladatunk az RxCpp **alkalmazása** (a `VenomBus` és `Scheduler` szintjén), nem pedig a könyvtár belső logikájának megváltoztatása.
* **Kivétel**: Csak akkor tekintünk bele, ha egy egyedi operátor vagy egy speciális scheduler (mint a mi `NullScheduler`-ünk) implementálása miatt pontosan látnunk kell egy belső sablon-definíciót.

#### 2. Stratégiai Jelentőség
* **Deklaratív Pipeline**: Lehetővé teszi, hogy a biztonsági eseményeket ne `if-else` láncokkal, hanem deklaratív adatfolyamokként kezeljük (pl. `.window_with_time()`, `.flat_map()`).
* **Absztrakció**: Elválasztja az üzleti logikát (mit csinálunk az adattal) az ütemezéstől (melyik szálon fut a művelet).

#### 3. Rögzített Kapcsolódási Pontok
* A White-Venom a következő RxCpp elemekre támaszkodik kritikus szinten:
    * `rxcpp::subjects::subject`: Az események belépési pontja.
    * `rxcpp::observe_on`: A `Cortex` és `Null` domének közötti váltáshoz.
    * `rxcpp::composite_subscription`: A rendszer tiszta leállításához (lifetime management).


    ### 📊 Jelentés: Telemetria és Metabolizmus - BusTelemetry

A `BusTelemetry` a White-Venom belső állapotfigyelő rendszere. Elsődleges feladata az eseményáramlási metrikák gyűjtése és a rendszer terheltségének (metabolizmusának) kiszámítása a dinamikus védekezéshez.

#### 1. Metabolikus Számítás (SystemMetabolism)
A rendszer a terhelést az események feldolgozási sebessége alapján határozza meg:
* **Reference Tick**: Egy 100.0 ms-os alapértékhez viszonyítva méri az események sűrűségét.
* **LoadFactor**: A `currentTickMs / referenceTickMs` hányadosa határozza meg a terheltségi mutatót.
* **Dinamikus hatás**: Ez a `loadFactor` közvetlen bemenete a `VenomBus` dinamikus entrópiás küszöbképletének ($Threshold_{dynamic} = 6.8 \times (1.0 / (loadFactor + 0.1))$).

#### 2. Adatstruktúra és Atomi Műveletek
* **Szálbiztosság**: Minden számláló (total, accepted, null_routed, dropped, queue_depth) `std::atomic` típusú, így a párhuzamosan futó reaktív worker-ek (Vent) és a döntéshozó szál (Cortex) egyszerre, zárolásmentesen frissíthetik a metrikákat.
* **Queue Monitoring**: Figyeli az aktuális (`queue_depth`) és a csúcsértékű (`peak_queue_depth`) várakozási sor mélységet, ami kritikus a DoS (Denial of Service) elleni védekezésben.

#### 3. TelemetrySnapshot
* **Pillanatkép technológia**: A `snapshot()` metódus egy konzisztens, kimerevített állapotot ad vissza a rendszerről.
* **Diagnosztikai adatok**: A snapshot tartalmazza a biztonsági profilt (`current_profile`), a busz állapotát (`state`) és az aktuális időablak hosszát (`window_ms`) is.

#### 4. Diagnózis a Context Package számára
* **Központi szerep**: A `VenomBus` minden egyes esemény betolásakor frissíti a telemetriát, így a rendszer válaszideje nanoszekundumos pontossággal követhető.
* **Időzítés**: A `std::chrono::steady_clock` használata garantálja, hogy a mérések monotonok maradnak, függetlenül a rendszeridő esetleges módosításaitól.


### 📋 Jelentés: Telemetria Típusok és Snapshot definíciók

A `TelemetryTypes.hpp` és `TelemetrySnapshot.hpp` állományok határozzák meg a White-Venom állapotgépének szókincsét. Ezek az állományok biztosítják a típusbiztonságot a `VenomBus`, a `BusTelemetry` és a felhasználói felület (UI/CLI) között.

#### 1. Rendszerállapotok (BusState)
A busz aktuális egészségi állapotát jelző enumeráció:
* **UP**: Normál működés.
* **DEGRADED**: Lassulás észlelhető, de a kiszolgálás folyamatos.
* **OVERLOAD**: Kritikus terhelés, a várólista megtelt.
* **NULL_ONLY**: Védelmi állapot, minden forgalom a `NullScheduler`-be irányítva.

#### 2. Biztonsági Profilok (SecurityProfile)
A rendszer védekezési szintjét határozza meg:
* **NORMAL**: Emberi léptékű, prediktálható eseményáramlás.
* **HIGH**: Rendszerindulás vagy fenyegetettség esetén alkalmazott szigorított profil.
* **LOCKDOWN**: Opcionális állapot a teljes forgalomkorlátozáshoz.

#### 3. TelemetrySnapshot (Adatstruktúra)
Egy összetett struktúra, amely a rendszer minden lényeges metrikáját egyetlen atomi csomagba gyűjti:
* **Traffic Metrics**: Összesített, elfogadott, eldobott és `null_routed` (elnyelt) események száma.
* **Queue Metrics**: Aktuális és csúcsértékű sorhosszúság a DoS detektáláshoz.
* **Dual-Venom bővítmények**:
    * `current_profile`: Az aktív biztonsági beállítás.
    * `time_cube_violations`: Az időzítési anomáliák száma.
    * `current_system_load`: A metabolikus `loadFactor` (ahol 1.0 a névleges terhelés).

#### 4. Diagnózis a Context Package számára
* **Header-only design**: Mivel nem tartalmaznak logikát, nincs szükség `.cpp` állományokra; ez gyorsítja a fordítást és egyszerűsíti az integrációt.
* **Kiterjeszthetőség**: A snapshot struktúra könnyen bővíthető újabb diagnosztikai mezőkkel anélkül, hogy a `BusTelemetry` belső logikáját módosítani kellene.


## include: 
### 🕰️ Jelentés: Idő-Referencia Rendszer - TimeCubeTypes

A `TimeCubeTypes.hpp` a White-Venom belső, viszonylagos időmérő rendszerének definícióit tartalmazza. Ez a modul teszi lehetővé a "Metabolism-Aware" működést, elválasztva a logikai időt (Tick) a fizikai időtől (ms).

#### 1. Rendszer Metabolizmus (SystemMetabolism)
[cite_start]A rendszer pillanatnyi "anyagcseréjét" három mutató határozza meg:
* [cite_start]**Reference Tick**: A kalibráció során rögzített alapérték (ms).
* [cite_start]**Current Tick**: A terhelés alatt mért tényleges eseménysűrűség (ms).
* **LoadFactor**: A fizikai és logikai idő hányadosa. [cite_start]Ha az érték > 1.0, a rendszer lassulást tapasztal, és ehhez igazítja a modulok időkeretét.

#### 2. Modul Időprofilok (ModuleTimeProfile)
[cite_start]Minden modul egy egyedi "Fekete Doboz" profillal rendelkezik, amely tartalmazza a futási elvárásokat:
* **Expected Cost (Ticks)**: A modul végrehajtási "ára" Tick-ekben kifejezve. [cite_start]Ez egy hardverfüggetlen állandó.
* **Tolerance Sigma**: A megengedett szórás. [cite_start]Szigorúbb moduloknál (pl. kriptográfia) alacsonyabb, I/O intenzív moduloknál magasabb.
* [cite_start]**Violation Count**: Számláló, amely rögzíti, hányszor lépte át a modul a számára kijelölt Time-Cube keretet.

#### 3. Idő-alapú Alapvonal (TimeCubeBaseline)
[cite_start]A teljes rendszer statikus lenyomata, amely a kalibráció időpontját és a profilok gyűjteményét tartalmazza egy `unordered_map`-ben. Ez az adatstruktúra szolgál alapul a `VenomBus` és a `Scheduler` számára a futásidejű döntéshozatalhoz.

#### 4. Diagnózis a Context Package számára
* [cite_start]**Elhelyezkedés**: Az állomány az `include/TimeCubeTypes.hpp` útvonalon található, közvetlenül a gyökér include könyvtárban.
* [cite_start]**Konzisztencia**: Közvetlenül beemeli a `telemetry/TelemetryTypes.hpp`-t, biztosítva, hogy a biztonsági profilok (Normal/High) és az időmérések szinkronban legyenek.


## include/src: utils


### 📜 Jelentés: Konfigurációs Templomok - ConfigTemplates

A `ConfigTemplates` modul tartalmazza a White-Venom által kikényszerített biztonsági irányelvek statikus definícióit. Ez a projekt "tudásbázisa", amely a Bash-alapú tervezési fázisból átemelt hardening szabályokat tárolja C++ adatszerkezetekben.

#### 1. Rendszermag Hardening (sysctl & Kernel)
* **SYSCTL_BOOTSTRAP_CONTENT**: Tartalmazza a kritikus hálózati és kernel védelmi vonalakat.
    * Kiemelt elem: `kernel.unprivileged_bpf_disabled=2` (maximális szigor a BPF ellen).
    * Tartalmazza a Yama ptrace scope és a fájlrendszer-védelem (protected_symlinks) beállításait.
* **KERNEL_HARDENING_PARAMS**: Egyetlen sztringben tárolja a GRUB/kernel indítási paramétereket.
    * Alkalmazott védelmek: `mitigations=auto`, `spectre_v2=on`, `lockdown=confidentiality`, és a memória inicializálás (`init_on_alloc=1`).

#### 2. Periféria és Protokoll Védelem
* **BLACKLIST_CONTENT**: Hardver-szintű tiltólista.
    * Tiltja a veszélyes interfészeket: `usb-storage`, `firewire`, `thunderbolt`.
    * Protokoll-szintű tiltás (install /bin/true): `dccp`, `sctp`, `rds`, `tipc`.
    * Tartalmaz specifikus WiFi (iwlwifi) energiagazdálkodási fixeket a stabilitás érdekében.

#### 3. Fájlrendszer és Fordítási Környezet
* **FSTAB_HARDENING_CONTENT**: A `/proc` (hidepid=2) és a `tmpfs` partíciók (nosuid, nodev) biztonsági opcióit határozza meg.
* **MAKE_CONF_CONTENT**: Meghatározza a White-Venom által elvárt fordítási zászlókat (`-fstack-protector-strong`) és a rendszerszintű `USE` flageket (pl. `-systemd`, `hardened`).

#### 4. Integritás Kontroll (Canary)
* **CANARY_CONTENT**: Egy belső ujjlenyomat, amely a telepítés dátumát, állapotát és a Zero-Trust modulok meglétét rögzíti. Ez szolgál alapul a rendszer integritásának gyors ellenőrzéséhez.

#### 5. Diagnózis a Context Package számára
* **Adatkezelés**: Az állomány `extern const` deklarációkat használ, biztosítva, hogy a sablonok csak egyszer, statikusan legyenek lefoglalva a memóriában.
* **Névtér**: A `VenomTemplates` névtér elkülöníti a nyers konfigurációs adatokat az üzleti logikától.


### 📜 Jelentés: Végrehajtási Irányelvek - ExecPolicy & Registry

Az `ExecPolicy` rendszer a White-Venom Zero-Trust modelljének egyik tartóoszlopa. Lehetővé teszi, hogy minden külső programhíváshoz szigorú strukturális és szemantikai korlátokat rendeljünk, megakadályozva a jogosulatlan paraméterezést.

#### 1. Az Irányelv Struktúrája (ExecPolicy)
Az `ExecPolicy` struktúra három szinten védi a rendszert:
* **Argumentumok száma (`maxArgs`)**: Korlátozza, hány paramétert fogadhat el a bináris.
* **Argumentum hossza (`maxArgLen`)**: Megakadályozza a puffertúlcsordulást célzó, extrém hosszú bemeneteket.
* **Szemantikai validáció (`validate`)**: Egy `std::function` alapú callback, amely mélységi ellenőrzést végez az argumentumok tartalmán (pl. tiltott kulcsszavak keresése).

#### 2. Központi Nyilvántartás (ExecPolicyRegistry)
A Registry egy **Singleton** mintát követő tároló, amely összefogja a rendszer összes futtatási szabályát:
* **Szabályok regisztrációja**: A `registerPolicy` metódus rendeli hozzá az irányelveket a binárisok abszolút útvonalához.
* **Biztonságos lekérés**: A `getPolicy` metódus szigorú hibaellenőrzéssel (runtime_error) adja vissza a szabályt; ha egy binárishoz nincs regisztrált szabály, a rendszer megtagadja a futtatást.

#### 3. Alapértelmezett Biztonság (initDefaults)
A rendszer indulásakor az `initDefaults` állítja fel az első védelmi vonalakat:
* **sysctl védelem**: Például a `/sbin/sysctl` hívásokat maximum 32 argumentumra és 128 karakteres hosszhordozóra korlátozza, valamint ráköti a `validateSysctlArgs` speciális ellenőrzőt.

#### 4. Diagnózis a Context Package számára
* **Típusbiztonság**: Az irányelvek az `unordered_map` alapú keresésnek köszönhetően $O(1)$ idő alatt elérhetőek a `SafeExecutor` számára.
* **Szemantikai szétválasztás**: Az irányelv deklarálja az elvárást (`ExecPolicy`), a Registry tárolja azt, míg a tényleges validációs logika (pl. `SysctlPolicy`) külön modulba szervezhető.


### 🛠️ Jelentés: Hardening Eszköztár - HardeningUtils

A `HardeningUtils` gyűjteménye tartalmazza azokat az alacsony szintű rendszerhívásokat és segédfüggvényeket, amelyek a fizikai hardening műveleteket hajtják végre. A modul támogatja a "DRY_RUN" üzemmódot a biztonságos tesztelés érdekében.

#### 1. Fájlrendszer Hardening & Integritás
* **Immutable Flag (Native-First)**: A `setImmutable` függvény közvetlen `ioctl` hívásokkal (`FS_IOC_SETFLAGS`) operál a fájlrendszer szintjén. Az `FS_IMMUTABLE_FL` flag beállításával a fájlok még root joggal is módosíthatatlanokká válnak, amíg a flag aktív.
* **Biztonságos Írás**: A `writeProtectedFile` implementációja biztosítja a konfigurációk konzisztens kiírását, mielőtt azokat a rendszer védetté (immutable) nyilvánítaná.
* **Automatikus Biztonsági Mentés**: A `createBackup` függvény a módosítások előtt `.bak` kiterjesztéssel menti az eredeti állapotot a `std::filesystem` használatával.

#### 2. Rendszer Sterilizálás (Legacy Cleanup)
* **Konfiguráció Tisztítás**: A `cleanLegacyConfigs` automatikusan eltávolítja a korábbi verziókból visszamaradt, esetleg ütköző `99-venom*` típusú sysctl konfigurációkat a `/etc/sysctl.d/` könyvtárból.
* **Szigorú Végrehajtás**: A törlési műveleteket a modul saját `fork/execv` hívásokon keresztül, shell közbeiktatása nélkül végzi el a `/usr/bin/rm` binárissal.

#### 3. Kernel és Boot Konfiguráció
* **GRUB Injekció**: Előkészített metódus (`injectGrubKernelOpts`) a kernel indítási paramétereinek (pl. `lockdown`, `spectre_v2`) automatizált beállításához.
* **FSTAB Hardening**: A `smartUpdateFstab` felelős a `/proc` és `tmpfs` partíciók biztonsági zászlóinak (pl. `hidepid=2`, `nosuid`) ellenőrzéséért és beállításáért.

#### 4. Diagnózis a Context Package számára
* **Zero-Trust Végrehajtás**: A `secureExec` függvény a `SafeExecutor`-hoz hasonlóan a "Prepared Statement" logikát követi, elválasztva a binárist az argumentumoktól a parancsinjekció elkerülése érdekében.
* **Hibakezelés**: A rendszer a `waitpid` és `WEXITSTATUS` makrókkal ellenőrzi minden külső művelet sikerességét.


### 🧵 Jelentés: Szövegkezelő Segédeszközök - StringUtils

A `StringUtils` modul alacsony szintű szövegmanipulációs függvényeket biztosít a White-Venom számára. Elsődleges célja a bemeneti adatok és konfigurációs sorok sanitizálása, biztosítva a determinisztikus parsing folyamatokat.

#### 1. Biztonságos Transzformációk
* **HTTPS Kényszerítés**: A `replaceHttpWithHttps` függvény biztosítja, hogy a konfigurációkban vagy URL-ekben szereplő nem biztonságos `http://` protokollok automatikusan a titkosított `https://` változatra cserélődjenek.
* **Univerzális Csere**: A `replaceAll` metódus hatékonyan kezeli a karakterlánc-helyettesítéseket, elkerülve a végtelen ciklusokat üres forrásstring esetén.

#### 2. Konfiguráció Tisztítás (Sanitization)
* **Trim Funkció**: A `trim` függvény eltávolítja a whitespace karaktereket a szöveg elejéről és végéről.
    * **Jelentőség**: Kritikus az olyan fájlok feldolgozásakor, mint az `/etc/fstab` vagy a tiltólisták, ahol a véletlen szóközök parsing hibákhoz vagy a szabályok megkerüléséhez vezethetnének.

#### 3. Technikai Megvalósítás
* **Modern C++ Standard**: Az implementáció a `std::find_if_not` algoritmust használja a hatékony whitespace kereséshez.
* **Névtér**: A `VenomUtils` névtér használata garantálja, hogy a segédfüggvények ne ütközzenek a standard könyvtár vagy más modulok azonosítóival.

#### 4. Diagnózis a Context Package számára
* **Könnyűsúlyú kialakítás**: A modul nem igényel külső függőségeket, tisztán a standard string könyvtárra épül.
* **Stabilitás**: A `replaceHttpWithHttps` metódus üres bemenet esetén azonnal üres stringgel tér vissza, megelőzve a memóriahibákat.


### 🛡️ Jelentés: Szemantikai Validáció - SysctlPolicy

A `SysctlPolicy` modul felelős a `sysctl` parancsnak átadott argumentumok mélységi ellenőrzéséért. Ez a komponens biztosítja, hogy csak szabályos `kulcs=érték` párok kerüljenek végrehajtásra, kizárva a rosszindulatú karakter-injekciókat.

#### 1. Formai Validáció (Key-Value Check)
* **Kényszerített Struktúra**: A `validateSysctlArgs` függvény ellenőrzi, hogy minden argumentum tartalmaz-e `=` karaktert.
* **Hibakezelés**: Amennyiben az argumentum nem felel meg a `kulcs=érték` formátumnak, a rendszer `std::runtime_error` kivételt dob, megszakítva a végrehajtási láncot.

#### 2. Injekció Elleni Védelem (Illegal Characters)
A szűrő aktívan keresi a shell-specifikus vezérlőkaraktereket, amelyek lehetővé tennék több parancs összefűzését:
* **Tiltott karakterek**: `;` (parancselválasztó), `&` (háttérfolyamat/logikai ÉS), `|` (pipe).
* **Biztonsági hatás**: Ez a védelem kiegészíti a `SafeExecutor` fork/execv alapú védelmét, egy második, szoftveres gátat emelve a támadók elé.

#### 3. Integráció az ExecPolicyRegistry-vel
* **Callback alapú működés**: A `validateSysctlArgs` függvényt az `ExecPolicyRegistry` regisztrálja a `/sbin/sysctl` binárishoz tartozó irányelvben.
* **Statikus ellenőrzés**: A validáció a tényleges folyamatindítás előtt fut le, így a hibás vagy gyanús hívások soha nem érik el az operációs rendszert.

#### 4. Diagnózis a Context Package számára
* **Könnyűsúlyú implementáció**: A modul minimális függőséggel rendelkezik, kizárva a bonyolult parser-ek használatát a gyorsabb válaszidő érdekében.
* **Típusbiztonság**: A `Venom::Security` névtérbe ágyazva garantálja az építőelemek logikai elkülönítését.

### 🏗️ Jelentés: Rendszer Inicializáló - VenomInitializer

A `VenomInitializer` a White-Venom keretrendszer környezeti sterilizációjáért és alapvető infrastruktúrájáért felelős modul. Ez hajtja végre azokat a "Phase 0-5" műveleteket, amelyek a motor biztonságos futási környezetét garantálják.

#### 1. Környezeti Sterilizáció (T0 fázis)
* **Purge Unsafe Environment**: A modul drasztikusan avatkozik be a folyamat környezetébe a kódinjekciós támadások ellen.
* **Feketelistás változók**: Törli az `LD_PRELOAD`, `LD_LIBRARY_PATH`, `PYTHONPATH`, `PERL5LIB` és az `IFS` változókat, ezzel kiiktatva a Python-alapú vagy könyvtár-behelyettesítéses eltérítéseket.

#### 2. Biztonságos Alapstruktúra (Secure Skeleton)
* **Könyvtárstruktúra**: Létrehozza a működéshez szükséges izolált mappákat: `/var/log/whitevenom`, `/var/log/Backup`, `/etc/venom`, `/run/venom`.
* **Szigorú Jogosultságok**: Minden létrehozott könyvtárat `0700` (rwx------) jogosultsággal lát el, így azokhoz kizárólag a root felhasználó férhet hozzá.

#### 3. Integritás Védelem (Canary Deployment)
* **Canary elhelyezés**: A `/etc/venom/integrity.canary` fájl létrehozásával jelzi a rendszer állapotát.
* **Immutable Zárolás**: A fájl írása után a `VenomUtils::setImmutable` hívással azonnal írásvédetté teszi azt a fájlrendszer szintjén, megakadályozva a későbbi manipulációt.

#### 4. Diagnózis a Context Package számára
* **Privilégium Ellenőrzés**: Az `isRoot()` függvény biztosítja, hogy a motor ne indulhasson el alacsonyabb jogosultsági szinten, ahol a hardening műveletek sikertelenek lennének.
* **Integráció**: Szorosan együttműködik a `HardeningUtils`-al a fájlműveletekhez és a `VenomTemplates`-al a canary tartalomhoz.


## 6. White-Venom: Lifecycle & Inter-Module Extension (v2.2)

### 6.1. Determinisztikus Leállási Protokoll (Graceful Shutdown)
A szálkezelési hibák és erőforrás-szivárgások elkerülése érdekében a leállás sorrendje kötött:

1.  **Monitor Stop:** Először a külső szenzorokat (pl. `FilesystemModule` inotify szál) kell leállítani, hogy ne érkezzen több új esemény.
2.  **Bus Flush:** A `VenomBus` befejezi a már bent lévő események feldolgozását.
3.  **Subscription Unsubscribe:** A `lifetime.unsubscribe()` hívással az RxCpp láncok megszakadnak.
4.  **Scheduler Stop:** A `Vent` (párhuzamos) és `Cortex` (szekvenciális) szálak leállítása.
5.  **Final Telemetry:** Az utolsó snapshot mentése a `/var/log/whitevenom/shutdown.log`-ba.

### 6.2. Külső Rendszerfüggőségek (Native Dependencies)
A szoftver futtatásához és fordításához az alábbi környezeti feltételek szükségesek:

* **Kernel:** Minimum 5.10+ (a `lockdown=confidentiality` és az ioctl `FS_IMMUTABLE_FL` miatt).
* **Library-k:** * `libattr1-dev`: Az extended attribútumok kezeléséhez.
    * `librxcpp-dev`: A reaktív motorhoz.
* **Capabilities:** A binárisnak `CAP_SYS_ADMIN`, `CAP_FOWNER` és `CAP_NET_ADMIN` jogkörökkel kell rendelkeznie (ha nem rootként fut).

### 6.3. Modulközi Kommunikációs Minta (IMC)
A modulok nem hivatkozhatnak egymásra közvetlenül. A kommunikáció kizárólag a `VenomBus`-on keresztül történik:

* **Esemény (Event):** `[SOURCE_MODULE] -> [ACTION_TYPE]: [PAYLOAD]` (pl. `FS_WATCH -> MODIFIED: /etc/shadow`).
* **Válaszreakció:** A `Cortex` kiértékeli az eseményt, és ha szükséges, egy `CortexCommand`-ot küld a célmodulnak.
* **Isolációs szabály:** Egyik modul sem blokkolhatja a buszt 10ms-nál hosszabb ideig (Time-Cube korlát).

### 6.4. Hibaelhárítási Alapvetések (Troubleshooting)
* **Zombie-szálak:** Ha a folyamat nem áll le `SIGINT`-re, az `inotify` blokkoló `read()` hívása ragadt be. Megoldás: `select()` timeout használata.
* **Bus Telítettség:** Ha a `loadFactor > 2.0`, a rendszer automatikusan `DEGRADED` állapotba vált és aktiválja a `NullScheduler` agresszív szűrését.
