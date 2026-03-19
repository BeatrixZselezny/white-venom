## 7. Private Module: Entropy-Based Key Rotation (Specifikáció)

### 7.1. Adat-szinkronizáció (Zero-Overhead Hook)
A bányász modul az RxCPP `Observable::doOnNext` vagy egy aszinkron `Subject` segítségével kapja meg a `NULL Scheduler`-be tartó bináris zajt. 
* **Izoláció:** A bányászati művelet (XOR-fúzió) egy elkülönített szálon fut, így a Stable ág ventilációs sebessége (throughput) változatlan marad.
* **Láthatatlanság:** Mivel nincs visszacsatolás a főág felé, a binárisban nem keletkezik mérhető késleltetés (jitter), ami elárulná a bányász jelenlétét.

### 7.2. Dinamikus Titkosítási Mechanizmus
A bányász nem csak tárolja az entrópiát, hanem közvetlenül a futásidejű titkosításba csatornázza:
1. **Entropy Injection:** A `StreamProbe` által azonosított 6.8+ entrópiájú csomagokat a modul beleforgatja a belső Master Key Stream-be.
2. **Time-Cube Trigger:** A kulcs tényleges frissítése (Rotation) akkor történik meg, amikor a 25 hardening modul belső ciklusideje (fiziológiai ritmusa) lejár.
3. **Végeredmény:** Egy olyan titkosított csatorna, aminek a kulcsait a támadó generálja, de a váltás ütemét a te rendszered szívverése határozza meg.
