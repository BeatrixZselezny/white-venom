# 🛡️ Venom RX Hardening Framework - VÉGLEGES ARCHITEKTÚRA

## 1. Az "RX-Bus" és a Dinamikus Eseménykezelés
A Venom RX nem szekvenciális, hanem **reaktív**. A rendszer lelke egy Dinamikus RX Busz, amely biztosítja a modulok közötti aszinkron, de függőség-vezérelt kommunikációt.

* **Dinamikus RX:** A modulok nem csak lefutnak, hanem szignálokat (Event) emittálnak a buszra. Ha a `00_install` kész, a `SIG_HW_READY` eseményre a TIER-1 modulok egyszerre reagálnak.
* **Prepared Statements (Kommunikációs Hardening):** Minden belső interakció (legyen az DB hívás a 13-as modulban vagy busz-üzenet) "előkészített utasításokon" keresztül zajlik. Ez megakadályozza az injektálásos támadásokat a hardening folyamat alatt is.

---

## 2. A "Fehér Méreg" Ütemezése (Minden Újítással)

| Tier | Ütem | Modul | Funkció | Innováció |
| :--- | :--- | :--- | :--- | :--- |
| **T0** | T+0s | 00_install | HW Mitigation & Bus Init | **Dinamikus RX Busz indítása.** |
| **T0** | T+1s | 18_stack_canary | Compiler Hardening | Prepared build-environment. |
| **T1** | T+2s | 12_banner_grab | Reconnaissance Fog | Stealth üzemmód aktiválása. |
| **T1** | T+3s | 20_ptrace_lock | Anti-Injection | Root-only ptrace (SIG_PTRACE_OFF). |
| **T1** | T+4s | 21_mount_opts | FS Hardening | /tmp, /proc zsilipelés. |
| **T1** | T+5s | 22_immutable | Physical Lock (chattr) | **Zero-Trust File Integrity.** |
| **T2** | T+6s | 19_pax_emul | Binary Immunization | Patchelf logic (No-ExecStack). |
| **T2** | T+7s | 23_mod_sign | LKM Signature Enforce | Kernel-space védelem. |
| **T2** | T+8s | 24_ssl_harden | TLS/Cipher Lockdown | Prepared SSL Contexts. |
| **T2** | T+9s | 25_mem_harden | ASLR & W^X | Memória-toxikológia aktiválása. |
| **T2** | T+10s | 17_kernel_lock | Final Lockdown | SIG_SYS_LOCKED emittálása. |

---

## 3. Adatbázis és Kommunikációs Védelem (Modul 13+)
* **Prepared Statements:** A PostgreSQL és minden belső API hívás során kötelező az előkészített utasítások használata. Ez a "fehér méreg" egyik legtisztább összetevője: a támadó nem tudja eltéríteni az SQL vagy rendszer-lekérdezéseket.



---

## 4. Kigyomlált és Tiltott Elemek (Legacy Purge)
* **UNBOUND:** Teljesen kiszervezve. Nem marad hátra legacy kód.
* **PYTHON:** A bootstrap fázisból száműzve.
* **TEMURIN:** Külső függőségként törölve.
* **BUILD-ESSENTIAL:** A fordítási fázis után (TIER-3) megsemmisítve.

---

## 5. Post-Install Főfolyamat (A Reboot utáni élet)
A **15-ös modul** alapján egy külön tervezési fázis következik a reboot után:
* A lezárt kernel melletti biztonságos adminisztráció.
* Dinamikus integritás-ellenőrzés a buszon keresztül.

---
**Audit Log:** 2025-12-26
**Architect:** [Gonosz Szeretet]
**Státusz:** Verified / RX-Ready
