#include "utils/ConfigTemplates.hpp"

namespace VenomTemplates {

    const std::vector<std::string> SYSCTL_BOOTSTRAP_CONTENT = {
        "# White Venom - Zero-Trust Bootstrap sysctl",
        "kernel.kptr_restrict=2",
        "kernel.dmesg_restrict=1",
        "kernel.printk=3 4 1 3",
        "kernel.unprivileged_bpf_disabled=2", // KRITIKUS: Maximális szigor (Lockdown)
        "net.core.bpf_jit_harden=2",
        "net.ipv4.conf.all.rp_filter=1",
        "net.ipv4.conf.default.rp_filter=1",
        "net.ipv4.conf.all.accept_source_route=0",
        "net.ipv4.conf.all.accept_redirects=0",
        "net.ipv4.conf.all.secure_redirects=1",
        "net.ipv4.conf.all.shared_media=0",
        "net.ipv4.conf.all.log_martians=1",
        "net.ipv4.tcp_syncookies=1",
        "net.ipv4.tcp_rfc1337=1",
        "fs.protected_fifos=2",
        "fs.protected_regular=2",
        "fs.protected_symlinks=1",
        "fs.protected_hardlinks=1",
        "kernel.yama.ptrace_scope=2"
    };

    const std::vector<std::string> BLACKLIST_CONTENT = {
        "# White Venom - Hardening Blacklist & WiFi fix",
        "blacklist usb-storage",
        "blacklist firewire-core",
        "blacklist thunderbolt",
        "blacklist floppy",
        "install dccp /bin/true",
        "install sctp /bin/true",
        "install rds /bin/true",
        "install tipc /bin/true",
        "install bluetooth /bin/true",
        "options iwlwifi power_save=0",
        "options iwlmvm power_scheme=1"
    };

    const std::string KERNEL_HARDENING_PARAMS = 
        "quiet splash mitigations=auto,nosmt spectre_v2=on spec_store_bypass_disable=on "
        "l1tf=full,force mds=full,nosmt tsx=off page_alloc.shuffle=1 "
        "slab_nomerge init_on_alloc=1 init_on_free=1 "
        "iommu=pt lockdown=confidentiality";

    const std::vector<std::string> FSTAB_HARDENING_CONTENT = {
        "proc      /proc        proc      defaults,hidepid=2            0     0",
        "tmpfs     /dev/shm     tmpfs     defaults,nodev,nosuid         0     0",
        "tmpfs     /run         tmpfs     defaults,nodev,nosuid         0     0",
        "devpts    /dev/pts     devpts    defaults,gid=5,mode=620       0     0"
    };

    const std::vector<std::string> MAKE_CONF_CONTENT = {
        "# White Venom Optimized Toolchain",
        "COMMON_FLAGS=\"-O2 -pipe -fstack-protector-strong -fstack-clash-protection -D_FORTIFY_SOURCE=2\"",
        "CHOST=\"x86_64-pc-linux-gnu\"",
        "USE=\"hardened nosuspnd -python -unbound -systemd\"", 
        "ACCEPT_LICENSE=\"*\"",
        "FEATURES=\"sandbox userpriv usersandbox\""
    };

    const std::vector<std::string> CANARY_CONTENT = {
        "--- WHITE VENOM INTEGRITY CANARY ---",
        "DEPLOYMENT_DATE: 2025-12-31",
        "STATUS: HARDENED",
        "ZERO_TRUST: ENABLED",
        "PYTHON_DEP: REMOVED",
        "UNBOUND_DEP: REMOVED",
        "FINGERPRINT: venom-integrity-check-2025"
    };
}
