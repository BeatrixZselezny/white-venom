# 🛡️ Venom RX Hardening Framework - Rendszer Architektúra

## 1. Architektúra Áttekintés
A Venom RX egy **reaktív, eseményvezérelt (RX Bus)** hardening keretrendszer Debian Trixie alapokon.

**Főbb vezérelvek:**
* **Zero Trust:** Minden modul tranzakciós lakatokat (`chattr +i`) használ.
* **Python-mentesség:** Csak natív eszközök (Bash, sed, awk, patchelf).
* **W^X (Write XOR Execute):** Memória védelem bináris és kernel szinten.

---

## 2. Prioritási Térkép (Scheduler)

| Ütem | Modul | Funkció | Kill Chain fázis gátlása |
| :--- | :--- | :--- | :--- |
| T+0s | 00_install | HW Flags (Spectre/Meltdown) | Exploitation |
| T+1s | 18_stack_canary | Compiler Hardening | Weaponization |
| T+2s | 12_banner_grab | Verzió elrejtés | Reconnaissance |
| T+3s | 20_ptrace_lock | Injektálás védelem (Yama) | Privilege Escalation |
| T+4s | 21_mount_opts | /tmp, /proc zsilipelés | Exploitation |
| T+5s | 22_immutable | Kritikus fájlok lezárása | Persistence |
| T+6s | 23_mod_sign | Kernel Modul aláírás | Installation |
| T+7s | 19_pax_emul | No-Exec Stack (patchelf) | Exploitation |
| T+8s | 24_ssl_harden | TLS 1.2+ & Cipher lock | Command & Control |
| T+9s | 25_mem_harden | ASLR & NULL-pointer | Exploitation |
| T+10s | 17_kernel_lock | Lockdown aktiválása | Actions on Objectives |

---

## 3. Technikai Audit Megállapítások

### 🧠 Memória Hardening (Modul 25)
* **ASLR:** `vm.mmap_rnd_bits = 28` (64-bit).
* **NULL-Pointer:** `vm.mmap_min_addr = 65536`.
* **OOM Viselkedés:** `vm.panic_on_oom = 1`.

### 📂 Fájl Integritás (Modul 22-23)
* Tranzakciós kezelés: `chattr -i` -> Módosítás -> `chattr +i`.
* Érintett fájlok: `/etc/shadow`, `/etc/sudoers`, `/etc/default/grub`, `/etc/resolv.conf`.

### 🛡️ Bináris Immunizálás (Modul 19)
* Minden bináris futtatható stack (EXECSTACK) bitje törölve a `patchelf` segítségével.

---

## 4. Teendők (Roadmap)
- [ ] **make.conf** véglegesítése (munkahelyi fájl alapján).
- [ ] **Python** maradékfüggőségek teljes kigyomlálása.
- [ ] **15-ös modul** post-install folyamatának megtervezése.
- [ ] Blacklist fájlok átnevezése `hardening_blacklist.conf`-ra.

---
**Státusz:** Auditált / Zero-Trust Ready
**Készült:** 2025-12-26
