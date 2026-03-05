# White-Venom Security Bootstrap Notes

## Context

This document captures architectural decisions and security design
choices made during the bootstrap refactor of the White-Venom framework.

The primary goal is a zero-trust, user-first, policy-driven system
that minimizes attack surface and avoids implicit privilege escalation.

---

## Key Design Decisions

### 1. User-first bootstrap (Zero Trust)
- No module assumes root privileges
- Privilege escalation is explicit, never implicit
- User-space preparation always precedes system hardening

### 2. Removal of SysctlModule
- Sysctl handling is not a standalone module
- Sysctl operations are treated as privileged capabilities
- Execution is controlled via SafeExecutor + ExecPolicyRegistry
- Prevents logic duplication and unsafe assumptions

### 3. InitSecurityModule (Ring 0.5)
- Single early bootstrap module
- Loads execution policies and input contracts
- Initializes security decision logic
- Does NOT perform destructive system changes by default

### 4. Prepared-execution model (SQL analogy)
- All system commands follow a prepared-statement pattern
- No shell invocation
- fork/exec only with validated arguments
- Structural + semantic validation enforced

### 5. VenomBus invariants
- Bus is never NULL
- All orchestration flows through the bus
- Modules do not communicate directly
- Telemetry is read-only and audit-safe

---

## Dry-Run Model

The `--dry-run` mode is audit-grade, not cosmetic.

Guarantees:
- No system state changes
- All intended actions are logged
- Privilege checks are still enforced
- Same code paths as real execution

Example outputs:
- Would write file: /etc/venom/integrity.canary
- Would apply sysctl: kernel.kptr_restrict=2
- Would register ExecPolicy: /sbin/sysctl

---

## Privilege Philosophy

Root access is treated as a loaded weapon.

Rules:
- No silent sudo
- No partial execution
- No fallback behavior
- Fail fast, fail loud

Root-only operations (future phases):
- Bootloader hardening
- Kernel parameter enforcement
- GRUB and persistence controls

These are intentionally excluded from the initial bootstrap.

---

## Next Planned Steps

### A. Capability-Based Privilege Model
- Replace binary root checks with declared capabilities
- Example capabilities:
  - FS_WRITE_SYSTEM
  - SYSCTL_WRITE
  - BOOT_MODIFY
- Privilege decisions made by the bus, not modules

### B. Root-Only Hardening Modules (Phase 2+)
- BootHardeningModule
- KernelHardeningModule
- Never auto-executed
- Explicit operator intent required

### C. Enhanced Audit Output
- Structured dry-run logs
- Machine-parseable audit format
- Deterministic execution traces

---

## Guiding Principle

Minimalism is security.

Smaller codebase → smaller attack surface  
Explicit intent → fewer surprises  
User-first → safer systems

