#ifndef CONFIGTEMPLATES_HPP
#define CONFIGTEMPLATES_HPP

#include <vector>
#include <string>

namespace VenomTemplates {

    // 0.15 - Hálózati és Fájlrendszer Hardening (sysctl)
    const std::vector<std::string> SYSCTL_BOOTSTRAP_CONTENT = {
        "# White Venom - Zero-Trust Bootstrap sysctl",
        "kernel.kptr_restrict=2",
        "kernel.dmesg_restrict=1",
        "kernel.unprivileged_bpf_disabled=1",
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
        "fs.protected_hardlinks=1"
    };

    // Kernel modul tiltások
    const std::vector<std::string> BLACKLIST_CONTENT = {
        "blacklist usb-storage",
        "blacklist firewire-core",
        "blacklist thunderbolt",
        "install dccp /bin/true",
        "install sctp /bin/true",
        "install rds /bin/true",
        "install tipc /bin/true"
    };

    // [ÚJ] "Széles spektrumú" Kernel Injekció Koktél
    // Csak a paraméterek, amiket a grub-editenv fog megkapni
    const std::string KERNEL_HARDENING_PARAMS = 
        "quiet splash mitigations=auto,nosmt spectre_v2=on spec_store_bypass_disable=on "
        "l1tf=full,force mds=full,nosmt tsx=off page_alloc.shuffle=1 "
        "slab_nomerge init_on_alloc=1 init_on_free=1";

    // T1 - Éles FSTAB Hardening (UUID-barát feldolgozáshoz)
    const std::vector<std::string> FSTAB_HARDENING_CONTENT = {
        "proc      /proc        proc      defaults,hidepid=2            0     0",
        "tmpfs     /dev/shm     tmpfs     defaults,nodev,nosuid  0     0",
        "tmpfs     /run         tmpfs     defaults,nodev,nosuid  0     0",
        "devpts    /dev/pts     devpts    defaults,gid=5,mode=620 0     0"
    };

    // Make.conf - Toolchain optimalizáció (Python és Unbound mentesítve)
    const std::vector<std::string> MAKE_CONF_CONTENT = {
        "COMMON_FLAGS=\"-O2 -pipe -fstack-protector-strong -D_FORTIFY_SOURCE=2\"",
        "CHOST=\"x86_64-pc-linux-gnu\"",
        "USE=\"hardened nosuspnd -python -unbound\"", // Python és Unbound kigyomlálva
        "ACCEPT_LICENSE=\"*\"",
        "FEATURES=\"sandbox userpriv usersandbox\""
    };
}

#endif
