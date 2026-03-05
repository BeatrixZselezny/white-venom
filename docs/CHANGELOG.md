# White Venom – CHANGELOG

## 2025-11-30 – Bootstrap Stabilizáció és Modulfa Refaktor
- Teljes modulfa újraszámozva (venom_modtree_renumber.sh).
- 02_grub_inject.sh archiválva → áthelyezve a `parking/` könyvtárba.
- 00_install.sh elejére beépítve a GRUB environment detect + auto-install mechanizmus.
- Orchestrator early-phase CPU hw_vuln injection integráció tervezve (a legelejére).

## [0.9.0] – 2025-11-30
### Added
- Integrated full environment sterilization layer into 00_install.sh:
  - PATH restriction to system binaries only
  - Removal of LD_* injection vectors
  - Reset of IFS
  - Purging of exported Bash functions (BASH_FUNC_*)
  - Locale hardening (LANG/LC_ALL = C)
  - Removal of Python/Ruby/Perl/Go/Node/Git poisoning vectors
- Added complete bootstrap sysctl lockdown phase:
  - IPv4 redirect/spoofing protections
  - Loopback bypass blocking
  - rp_filter strict mode
  - shared_media baseline for transitional IPv4 stage
  - Filesystem LPE protections (protected_symlinks, protected_hardlinks, fifos, regular)
  - Kernel info-leak and BPF-restriction shields
  - Yama ptrace_scope baseline for Debian Trixie
- Introduced `/etc/sysctl.d/00_whitevenom_bootstrap.conf` with atomic write semantics.
- Added detection of malicious/symlinked sysctl target files.

### Changed
- Refactored 00_install.sh to include GRUB environment detection as *first-stage baseline*:
  - Auto-detect `grub-editenv` or `grub2-editenv`
  - If missing → auto-install `grub-common` + `grub2-common`
  - Added kernelopts baseline initializer (reads `/proc/cmdline`)
- Moved all early-boot defensive steps before package installation to reduce attack surface.
- Reorganized bootstrap sequence into strictly ordered, atomic phases:
  1. Environment sanitization
  2. Sysctl lockdown
  3. GRUB environment assurance
  4. Toolchain/security baseline installation
  5. ldconfig sanity
  6. Baseline directories
  7. Canary initialization

### Removed
- Old 02_grub_inject.sh moved to `parking/` directory (archived legacy logic).

### Security Impact
- Eliminates class of env-based root-escalation attacks.
- Prevents early-phase routing/DNS manipulation during bootstrap.
- Eliminates user-space path poisoning.
- Secures GRUB environment before any userland modifications occur.

## 2025-11-30 – 00_install.sh audit & dry-run szakasz lezárva

### Áttekintés
A White Venom bootstrap első modulja (00_install.sh) sikeresen teljesítette az
életciklus auditjának első részét. A modul dry-run üzemmódban hibamentesen futott,
a beépített védelem, sorrend, és bootstrap logika teljes mértékben megfelel a
specifikációnak.

### Rögzített eredmények
- ENV sterilizálási baseline lefutott (PATH reset, LD_* törlés, TMPDIR és IFS fix).
- Sysctl-központú kernel/hálózati/file-system lockdown szekvencia sikeresen
  szimulálva (`00_whitevenom_bootstrap.conf`).
- A GRUB environment baseline felismerése és szimulált inicializálása megtörtént
  (`grub-editenv` jelen, fallback nem szükséges).
- APT műveletek hibamentesen szimulálva (toolchain, memguard deps, security baseline).
- ldconfig runtime ellenőrzés 0 hiba mellett lefutott.
- Baseline könyvtárak létrehozása szimulálva (/var/log/whitevenom, /var/tmp/whitevenom).
- Canary marker szimulált létrehozása sikeres.
- A modul teljesítette a tervezett 7-lépcsős bootstrap pipeline 1. fázisát.

### Következtetés
A 00_install.sh modul implementációja stabil, determinisztikus, és megfelel a
White Venom bootstrap alapelveinek. A dry-run alapján a modul készen áll a
sandbox környezetben történő integrációs tesztre (apply mód), azonban éles
rendszeren nem futtatandó.

### Következő lépés
- 01_orchestrator.sh audit szakasz indítása.
- Sandbox (VS) környezet tervezési dokumentum előkészítése, de még nem buildeljük.
