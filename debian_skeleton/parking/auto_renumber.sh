#!/bin/bash

set -euo pipefail

MODE="${1:-}"
if [[ "$MODE" != "--dry-run" && "$MODE" != "--apply" ]]; then
    echo "Használat: $0 [--dry-run | --apply]"
    exit 1
fi

declare -A MAP=(
  ["03_dns_quad9.sh"]="02_dns_quad9.sh"
  ["04_sysctl_ip6tables-security.sh"]="03_sysctl_ip6tables-security.sh"
  ["05_ipv6_worm_protection.sh"]="04_ipv6_worm_protection.sh"
  ["06_dpkg_apt_hardening.sh"]="05_dpkg_apt_hardening.sh"
  ["07_essential_packages.sh"]="06_essential_packages.sh"
  ["08_audispd_rules.sh"]="07_audispd_rules.sh"
  ["09_sysv_init_hardening.sh"]="08_sysv_init_hardening.sh"
  ["10_apparmor_config_hardening.sh"]="09_apparmor_config_hardening.sh"
  ["11_user_ssh_hardening.sh"]="10_user_ssh_hardening.sh"
  ["12_fluxbox_hardening.sh"]="11_fluxbox_hardening.sh"
  ["13_banner_grabbing_hardening.sh"]="12_banner_grabbing_hardening.sh"
  ["14_postgresql_hardening.sh"]="13_postgresql_hardening.sh"
  ["15_time_integrity_hardening.sh"]="14_time_integrity_hardening.sh"
  ["16_dev_init.sh"]="15_dev_init.sh"
  ["17_module_blacklist.sh"]="16_module_blacklist.sh"
  ["18_kernel_cmdline_lockdown.sh"]="17_kernel_cmdline_lockdown.sh"
  ["19_stack_canary_enforce.sh"]="18_stack_canary_enforce.sh"
  ["20_pax_emulation_layer.sh"]="19_pax_emulation_layer.sh"
  ["21_ptrace_lockdown.sh"]="20_ptrace_lockdown.sh"
  ["22_mount_opts_hardening.sh"]="21_mount_opts_hardening.sh"
  ["23_immutable_critical_paths.sh"]="22_immutable_critical_paths.sh"
  ["24_module_signing_config.sh"]="23_module_signing_config.sh"
  ["25_ssl_cipher_hardening.sh"]="24_ssl_cipher_hardening.sh"
  ["26_memory_exec_hardening.sh"]="25_memory_exec_hardening.sh"
)

echo "[INFO] White Venom auto-renumber – MODE: $MODE"

for OLD in "${!MAP[@]}"; do
    NEW="${MAP[$OLD]}"

    if [[ ! -f "$OLD" ]]; then
        echo "[SKIP] $OLD nem található"
        continue
    fi

    if [[ -f "$NEW" ]]; then
        echo "[ERROR] $NEW már létezik! Nem írom felül."
        exit 2
    fi

    if [[ "$MODE" == "--dry-run" ]]; then
        echo "[DRY]  $OLD → $NEW"
    else
        echo "[APPLY] $OLD → $NEW"
        mv "$OLD" "$NEW"
    fi
done

echo "[INFO] Kész."
