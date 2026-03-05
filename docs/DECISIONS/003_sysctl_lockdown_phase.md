# White Venom – Sysctl Lockdown Phase (ID: 003)

## Summary
A bootstrap első harmadában egy kötelező kernel/network/filesystem lockdown
fut le, mielőtt bármilyen online vagy csomagkezelési művelet történne.

## Motiváció
- IPv4 routing manipuláció a teljes APT folyamat kompromittálásához vezethet.
- Régi IPv4 redirect spoofing technikák (CVE-típusú) a mai napig működnek.
- Több LPE technika a protected_symlinks / protected_hardlinks hiányán múlik.
- Debian Trixie Yama ptrace_scope alapértelmezetten 0 → támadási felület.

## Lockdown Elements

### Network (IPv4)
- `accept_redirects = 0`
- `send_redirects = 0`
- `secure_redirects = 1`
- `accept_source_route = 0`
- `accept_local = 0`
- `rp_filter = 1`
- `shared_media = 0`

### Filesystem
- `fs.protected_symlinks = 1`
- `fs.protected_hardlinks = 1`
- `fs.protected_fifos = 1`
- `fs.protected_regular = 1`

### Kernel Security
- `kernel.kptr_restrict = 2`
- `kernel.dmesg_restrict = 1`
- `kernel.unprivileged_bpf_disabled = 1`

### Yama / ptrace
- `kernel.yama.ptrace_scope = 1`

## Execution Timing
A sysctl lockdown a **legelső** fázisok között fut:
- közvetlenül az env-sterilizer után
- APT előtt
- GRUB environment baseline előtt

## Security Benefit
- DNS hijack és MITM elleni védelem már a legelső pillanatban életbe lép
- Csökkentett heap-stack info-leak
- LPE attack surface minimumra csökkentve
