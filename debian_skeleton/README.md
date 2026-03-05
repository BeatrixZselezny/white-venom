# White Venom Security Framework (RC1)

![License](https://img.shields.io/badge/license-Proprietary-red)
![Status](https://img.shields.io/badge/status-STABLE-green)
![Build](https://img.shields.io/badge/build-HARDENED-blue)

**White Venom** is a reactive, privilege-separated security orchestration engine for Debian-based systems. It utilizes RxCpp for asynchronous event handling and strict hardening policies.

## 🏗️ Architecture
The system is built on a unidirectional data flow (VenomBus) to prevent deadlocks and race conditions.
See `plan/global_dependency_map.md` for the full architectural graph.

## 🚀 Build Instructions (Release Candidate 1)

This project uses a hardened Makefile configuration enforcing **Static Linking** and **Stack Protection**.

### Prerequisites
```bash
sudo apt install build-essential git
```

### Compilation
To build the static binary `bin/venom_engine`:

```bash
make clean && make all
```

The output binary is self-contained and does not require external libraries at runtime.

### Usage
Run with elevated privileges for system hardening, or use dry-run for simulation:

```bash
sudo ./bin/venom_engine --dry-run
```

## 🛡️ Security Features
- **RELRO & NOW:** Full Relocation Read-Only / Immediate Binding.
- **Stack Clash Protection:** GCC 14 hardened flags enabled.
- **Privilege Separation:** Core logic runs isolated from system execution.

---
© 2026 Beatrix Zselezny. All rights reserved.
# White-Venom: Protected by 2835+ drops
