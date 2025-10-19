### Rendszerszintű és kernel-hardening bővítések

#16_kernel_syscall_restrictions.sh
- limitálja az elérhető syscalokat pl. seccomp-bpf policy-vel (kompatibilis a 00 install memguard koncepcióval).
Tartalmazhat:

/etc/sysctl.d/99-seccomp.conf generálást
- audit loggal kísért tiltólista (pl. keyctl, userfaultfd, ptrace, kexec_load, stb.)

- 17_module_blacklist.sh
 kernel modul blacklisting (modprobe.d/blacklist.conf):
 tiltottak: firewire, dccp, sctp, bluetooth, usb-storage, cramfs, hfs, udf
 opcionálisan “immutable” kernel paraméter zárral a végén (sysctl kernel.modules_disabled=1)

- 18_kernel_cmdline_lockdown.sh
 /etc/default/grub hardening (már részben benne a 01-ben, de lehet explicit):
 - lockdown=confidentiality
 - slab_nomerge
 - mce=0
 - no_timer_check
 - pti=on
 - vsyscall=none
 - page_poison=1
 - init_on_free=1
 - init_on_alloc=1

# Memória és process isolation finomítás
 19_stack_canary_enforce.sh
 GCC/Clang környezethez és glibc confighoz -fstack-protector-strong kikényszerítése a build környezetekre
 (ha később más csomagok is épülnek).

 20_pax_emulation_layer.sh
 Szoftveres PaX emuláció (pl. execstack -q /usr/bin/* scan + automatikus --clear-execstack patching).

# 21_ptrace_lockdown.sh
 kernel.yama.ptrace_scope=3 (vagy legalább 1)
 logolja ha bármi megpróbál ptrace-t hívni.

# Fájlrendszer / Storage hardening
```bash
/tmp noexec,nosuid,nodev
/var/tmp noexec,nosuid,nodev
/home nodev
/boot noexec,nodev
```
findmnt-ből auto generált audit log.

# 23_immutable_critical_paths.sh
- kritikus fájlok chattr +i logikai védelme:
/etc/passwd, /etc/shadow, /etc/ld.so.conf.d/*, /etc/resolv.conf, /etc/ssh/sshd_config
- de csak post-install fut, nehogy build-et blokkoljon.

# Service és daemon réteg
- 24_cron_hardening.sh
 /etc/cron.* owner check, + chmod 700, + audit szabály hogy csak root futtathat.

# 25_logging_chain_audit.sh
- journald, rsyslog, auditd egységesítés, rotálás és integrity hash mentés.
Hash: sha256sum /var/log/* | tee /var/backups/log_hashes_$(date +%F).txt

## Networking finomítások

# 26_ip4tables_cleanup.sh
- IPv4 tűzfal fallback – ha IPv6 down, akkor is minimal deny policy.
DROP alap, logolva LOG --log-prefix "IPV4-DROP: ".

# 27_tls_hardening.sh
- /etc/ssl/openssl.cnf cipher suite limit:
```ini
MinProtocol = TLSv1.2
CipherString = HIGH:!aNULL:!MD5:!3DES
```
update-ca-certificates --fresh futás.

Rendszer integritás + baseline mentés

# 28_system_baseline_snapshot.sh
- find /etc /usr /bin /sbin -type f -exec sha256sum {} \; > /var/backups/baseline.sha256
- majd hetente diff log.

# 29_audit_startup_integrity.sh
- init.d szintű audit check, ami bootkor validálja a baseline hash-eket,
ha eltérés van: wall broadcast és lockout.

## Extra „meta-hardening” ötletek

# 30_virtualization_detection.sh
- VM detektálás (KVM, VMware, HyperV) és speciális sysctl finomhangolás
(pl. nohz_full=, kvm.nx_huge_pages=off).

# 31_usb_autorun_lock.sh
- automount kikapcsolása, udisks2 maszk, és udevadm filter a /media-ra.

# 32_firmware_hardening.sh
- fwupd sandbox, modprobe.d/firmware_blacklist.conf, és UEFI firmware hash baseline
(efivar --list → mentés).

## Végső dokumentáció

# README_SKELL_FULL_HARDENING.md
Tartalmazza:

- minden script célját (1 sorban)
- dependency gráfot (melyik mi után fut)
- hardening szint (L1 = baseline, L2 = paranoid)
- rollback menüpont: mit ne csináljon restore előtt

# 16_kernel_syscall_restrictions.sh

- cél: seccomp, ptrace, kexec, keyctl, userfaultfd stb. tiltása

# 17_module_blacklist.sh

- kernel modulok és fájlrendszerek letiltása

# 18_mount_opts_hardening.sh

- mount flag-ek (noexec, nosuid, nodev) automatikus és auditált beállítása






✅ 22_mount_opts_hardening.sh
→ minden kritikus partícióhoz:
