#!/usr/bin/env bash
# 91_wv00_selfcheck.sh — White Venom 00_install verification
#
# Purpose:
#   Verify that the major 00_install.sh outcomes are present and active.
#   This is a CHECKER only (read-only except for calling sysctl queries).
#
# Usage:
#   ./91_wv00_selfcheck.sh
#   sudo ./91_wv00_selfcheck.sh   (recommended for full visibility)

set -euo pipefail

ok=0; warn=0; fail=0
say(){ printf '%s\n' "$*"; }
pass(){ ok=$((ok+1)); say "[OK]   $*"; }
w(){ warn=$((warn+1)); say "[WARN] $*"; }
bad(){ fail=$((fail+1)); say "[FAIL] $*"; }

need_root=0
if [[ "$(id -u)" -ne 0 ]]; then
  need_root=1
  w "Not running as root. Some checks may be incomplete. (Run with sudo for full coverage.)"
fi

as_root() {
  if [[ "$need_root" -eq 1 ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

file_exists(){ [[ -e "$1" ]]; }
dir_perm_is(){ local d="$1" want="$2"; [[ "$(as_root stat -c '%a' "$d" 2>/dev/null || true)" == "$want" ]]; }

section(){ say; say "== $* =="; }

section "Phase 5.0 Canary"
if file_exists /etc/whitevenom_canary; then
  pass "/etc/whitevenom_canary exists"
  as_root ls -l /etc/whitevenom_canary || true
else
  bad "Missing /etc/whitevenom_canary"
fi

section "Phase 4.0 Baseline dirs"
if file_exists /var/tmp/whitevenom; then
  pass "/var/tmp/whitevenom exists"
  as_root ls -ld /var/tmp/whitevenom || true
else
  w "/var/tmp/whitevenom missing (may be created later in flow)"
fi

if file_exists /var/backups/skell_backups; then
  pass "/var/backups/skell_backups exists"
  as_root ls -ld /var/backups/skell_backups || true
else
  bad "Missing /var/backups/skell_backups"
fi

if file_exists /var/backups/skell_backups/grub_inject; then
  pass "/var/backups/skell_backups/grub_inject exists"
  as_root ls -ld /var/backups/skell_backups/grub_inject || true
  if dir_perm_is /var/backups/skell_backups/grub_inject 700; then
    pass "grub_inject perms 0700"
  else
    w "grub_inject perms not 0700"
  fi
else
  w "Missing /var/backups/skell_backups/grub_inject (created on first GRUB inject run)"
fi

section "Phase 3.0 ldconfig sanity"
if file_exists /var/log/whitevenom_ld_writable.log; then
  pass "LD sanity log exists: /var/log/whitevenom_ld_writable.log"
  as_root tail -n 5 /var/log/whitevenom_ld_writable.log || true
else
  w "LD sanity log missing: /var/log/whitevenom_ld_writable.log"
fi

section "Phase 2.0 Package baseline"
pkgs=(build-essential gcc make curl wget ca-certificates gnupg pkg-config libelf-dev apparmor apparmor-utils auditd)
for p in "${pkgs[@]}"; do
  if as_root dpkg -s "$p" >/dev/null 2>&1; then
    pass "pkg installed: $p"
  else
    w "pkg not installed: $p"
  fi
done
# headers for current kernel (best-effort)
krel="$(uname -r)"
if as_root dpkg -s "linux-headers-$krel" >/dev/null 2>&1; then
  pass "pkg installed: linux-headers-$krel"
else
  w "pkg not installed: linux-headers-$krel"
fi

section "Phase 1.x GRUB hardening"
cmdline="$(cat /proc/cmdline || true)"
say "cmdline: $cmdline"
must_tokens=( "pti=on" "spec_store_bypass_disable=seccomp" "slab_nomerge=yes" "mce=0" "l1tf=full,force" "smt=full,nosmt" )
missing=0
for t in "${must_tokens[@]}"; do
  if grep -q -- "$t" <<<"$cmdline"; then :; else missing=$((missing+1)); fi
done
if [[ "$missing" -eq 0 ]]; then
  pass "/proc/cmdline contains hardening tokens"
else
  w "/proc/cmdline missing $missing hardening tokens (verify /etc/default/grub + update-grub)"
fi

if file_exists /etc/default/grub; then
  pass "/etc/default/grub exists"
  as_root grep -E '^GRUB_CMDLINE_LINUX(_DEFAULT)?=' /etc/default/grub || true
else
  bad "Missing /etc/default/grub"
fi

if as_root command -v grub-editenv >/dev/null 2>&1; then
  pass "grub-editenv present"
  as_root grub-editenv - list || true
else
  w "grub-editenv not found"
fi

section "Phase 0.15 Sysctl bootstrap"
if file_exists /etc/sysctl.d/00_whitevenom_bootstrap.conf; then
  pass "/etc/sysctl.d/00_whitevenom_bootstrap.conf exists"
  as_root head -n 5 /etc/sysctl.d/00_whitevenom_bootstrap.conf || true
else
  w "Missing /etc/sysctl.d/00_whitevenom_bootstrap.conf"
fi

# Spot-check a few critical runtime sysctls
spot=(
  "kernel.unprivileged_bpf_disabled"
  "kernel.dmesg_restrict"
  "kernel.kptr_restrict"
  "fs.protected_hardlinks"
  "fs.protected_symlinks"
  "net.ipv6.conf.all.accept_redirects"
  "net.ipv6.conf.all.accept_source_route"
)
for k in "${spot[@]}"; do
  if as_root sysctl -n "$k" >/dev/null 2>&1; then
    v="$(as_root sysctl -n "$k" 2>/dev/null || true)"
    pass "runtime sysctl $k = $v"
  else
    w "runtime sysctl key not readable: $k"
  fi
done

section "Phase 1.5 APT pinning (systemd block)"
if file_exists /etc/apt/preferences.d/99systemd-noinstall; then
  w "systemd pin file present: /etc/apt/preferences.d/99systemd-noinstall (on a systemd host this may be 'dev-only questionable')"
  as_root sed -n '1,120p' /etc/apt/preferences.d/99systemd-noinstall || true
else
  pass "No systemd pin file found (ok on dev/systemd host)"
fi

say
say "== SUMMARY =="
say "OK: $ok  WARN: $warn  FAIL: $fail"
if [[ "$fail" -gt 0 ]]; then
  exit 1
fi
