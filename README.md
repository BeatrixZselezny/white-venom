# White Venom

> **Security-first Debian hardening framework**  
> *Originally Bash. Evolving into C++.*

## Overview

**White Venom** is a security-hardening framework focused on **Debian-based systems**, designed to apply **aggressive, layered system hardening** in a deterministic and auditable way.

The project started as a large, orchestrated **Bash-based hardening system** and is now in the process of being **re-architected into a C++ core**, while still retaining shell scripts where they make sense (bootstrapping, early-stage system interaction).

This is **not** a beginner-friendly project. It assumes:

* deep familiarity with Linux internals
* understanding of Debian packaging, boot process, kernel hardening
* willingness to break and rebuild systems

---

## Why Bash → C++

The original Bash implementation proved effective but hit hard limits:

* complexity explosion
* weak typing and poor refactoring guarantees
* limited testability
* orchestration logic becoming fragile

The C++ rewrite aims to provide:

* **strongly typed core orchestration**
* explicit dependency graphs between hardening stages
* reusable, testable modules
* better long-term maintainability

> Bash is still used where it is *the right tool*. White Venom is **not** a dogmatic rewrite.

---

## Project Status

⚠️ **Early transition phase**

* Bash-based hardening is **functional and extensive**
* C++ core exists but is **under active development**
* APIs, directory layout, and abstractions may change

Think of it as:

> *A Ferrari on jack stands — the engine is being rebuilt.*

---

## Repository Layout (High Level)

```
white-venom/
├── debian_skeleton/        # Core hardening system (Bash + C++)
├── scripts/                # Supporting / helper scripts
├── docs/                   # Documentation
├── plan/                   # Design notes and planning artifacts
├── CMakeLists.txt          # C++ build system entry point
├── README.md               # (this file)
├── CHANGELOG.md
└── LICENSE.md
```

---

## debian_skeleton/

This directory contains the **heart of White Venom**.

### Bash hardening stages

The numbered scripts represent **ordered hardening phases**:

```
00_install.sh
01_orchestrator.sh
02_dns_quad9.sh
...
25_memory_exec_hardening.sh
```

Each stage targets a **specific attack surface**:

* kernel behavior
* memory protections
* userspace hardening
* networking
* services
* filesystem immutability

The numbering is intentional and meaningful.

---

### C++ Core

The emerging C++ implementation lives here:

```
debian_skeleton/
├── include/
│   ├── core/        # Core abstractions, orchestration logic
│   ├── modules/     # Hardening modules (C++)
│   ├── telemetry/   # Logging / observability
│   ├── utils/       # Shared utilities
│   └── TimeCubeTypes.hpp
│
├── src/
│   ├── core/
│   ├── modules/
│   ├── telemetry/
│   ├── utils/
│   └── main.cpp
```

#### Design goals

* explicit execution graph instead of implicit script order
* separation between **what** is hardened and **how**
* future support for dry-run, audit-only, and rollback modes

---

## Build (C++ Core)

Basic out-of-tree build:

```bash
mkdir build
cd build
cmake ..
make
```

> Expect build system changes while the architecture stabilizes.

---

## Usage Philosophy

White Venom is **not**:

* a one-click security tool
* a general-purpose hardening script
* safe to run blindly on production systems

White Venom **is**:

* a framework for **intentional system lockdown**
* designed for disposable VMs, labs, hardened hosts
* meant to be read, understood, and adapted

If you don’t understand what a stage does:

> **Do not run it.**

---

## Security Model

* assumes hostile local and remote environments
* prioritizes kernel and memory protections early
* favors immutability over convenience
* accepts reduced usability as a tradeoff

---

## Documentation

Additional documentation can be found in:

* `docs/`
* `debian_skeleton/docs/`
* `plan/`

Many design decisions are documented **inline**, close to the code.

---

## License

See `LICENSE.md`.

---

## Final Note

White Venom is opinionated.

It reflects the idea that:

> *A system should earn the right to do things.*

If that philosophy resonates with you — you are the target audience.

