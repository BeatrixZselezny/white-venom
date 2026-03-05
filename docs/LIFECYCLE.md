# White Venom – Életciklus Dokumentum

Ez a dokumentum összefoglalja a White Venom hardening rendszer
architektúráját, működési alapelveit és evolúciós életciklusát.

---

## 1. Modulok életciklusa
A modulok számozása a rendszer boot- és security-sorrendjét követi.
A számozás akkor változik, ha:
- új modul kerül be középre,
- existing modul archiválásra kerül (parking),
- architekturális refaktor történik.

A `parking/` könyvtár tárolja azokat a modulokat, amelyek már nem futnak,
de történeti vagy referenciacélból megőrzésre kerülnek.

---

## 2. Bootstrap filozófia
A hardening három fő bootstrap-szakaszban fut:

**1) 00-install baseline**
- A kritikus csomagok biztos telepítése.
- A GRUB environment kezelőeszközök meglétének garantálása.
- A teljes rendszer baseline környezetének előkészítése.

**2) Orchestrator (01)**
- Early-phase CPU vulnerability mitigation.
- Futtatási mód értelmezés (dry-run / apply / audit / snapshot).
- A modulok determinisztikus sorrendben történő futtatása.

**3) 02–25 modulok**
- Specifikus hardening feladatok (sysctl, apt, kernel, ptrace, mountopts, stb).
- Mindegyik modul stateless és idempotens kialakítású.

---

## 3. Integrációs elvek
- A GRUB/kernelopts manipuláció mindig bootstrap elején történik.
- A CPU-mitigációs folyamatnak a rendszer indulása előtt kell érvényesülnie.
- A modulok hibamentes futásának előfeltétele: tiszta baseline.
- A rendszer self-healing: fallback mechanizmus az orchestratorban.

---

## 4. Dokumentációs szerkezet
- A történeti eseményeket a `CHANGELOG.md` követi.
- A nagy döntések a `docs/DECISIONS/` könyvtárban találhatók.
- A működési modell és életciklus a LIFECYCLE.md dokumentumban szerepel.
