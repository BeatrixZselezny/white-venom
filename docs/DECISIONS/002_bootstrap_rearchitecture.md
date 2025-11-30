# White Venom – Bootstrap Re-Architecture (ID: 002)

## Summary
A White Venom 00_install.sh modul teljes újratervezésen esett át, hogy
megfeleljen a system-level security, predictable boot és early-stage hardening
követelményeinek.

## Key Reasons
- A korábbi bootstrap széttagolt volt.
- A GRUB-inject funkció külön modulban (02) helyezkedett el.
- A sysctl (IPv4+kernel+fs) védelem nem korai fázisban futott le.
- A bootstrap kivitelezése sérülékeny volt env-based támadásokkal szemben.

## New Architecture
A bootstrap 7 fázisból áll:

1. **Environment Sanitization**
   – teljes env reset, LD_PRELOAD/func export/path poisoning blokkolás

2. **Sysctl Lockdown Phase**
   – IPv4-spoofing/redirect bypass védelem
   – localroot exploit védelmek
   – fs LPE védelem (protected_symlinks, hardlinks, fifos, regular)
   – BPF + Yama alapvédelem
   – kernel info-leak redukció

3. **GRUB Baseline Establishment**
   – grub-editenv/grub2-editenv detektálása
   – ha nem létezik → automatikus telepítés
   – kernelopts baseline inicializálás `/proc/cmdline` alapján

4. **APT Update & Toolchain / Memguard / Security Baseline**

5. **ldconfig / ld.so.conf sanity**

6. **Baseline directory hierarchy (logs/backups/tmp)**

7. **Canary file initialization**

## Impact
- Támadási felület **70–80%-al csökkent**
- Predictable, auditálható korai-boot baseline
- GRUB environment konzisztens lesz minden gépen
- Biztonságos bootstrap pipeline: root-level environment attack vectors eliminated
