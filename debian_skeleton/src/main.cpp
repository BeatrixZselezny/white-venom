// © 2026 Beatrix Zselezny
// White-Venom Security Framework

#include <iostream>
// POSIX umask for early filesystem hardening
#include <sys/stat.h>
#include <memory>
#include <string>
#include <vector>

#include <unistd.h>
#include <sys/prctl.h>
#include <sys/resource.h>
#include <linux/seccomp.h>

// Core
#include "core/VenomBus.hpp"
#include "core/Scheduler.hpp"
#include "core/SafeExecutor.hpp"

// Modules
#include "modules/SysctlModule.hpp"

[[noreturn]] static void hard_fail() {
    _exit(127);
}

static void early_hardening() {
    if (clearenv() != 0) hard_fail();

    if (setenv("PATH", "/usr/sbin:/usr/bin:/sbin:/bin", 1) != 0)
        hard_fail();

    if (prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) != 0)
        hard_fail();

    if (prctl(PR_SET_DUMPABLE, 0) != 0)
        hard_fail();

    struct rlimit rl {};
    rl.rlim_cur = rl.rlim_max = 0;
    if (setrlimit(RLIMIT_CORE, &rl) != 0)
        hard_fail();

    umask(077);

    // Mandatory seccomp baseline (no probing)
    if (prctl(PR_SET_SECCOMP, SECCOMP_MODE_STRICT) != 0)
        hard_fail();
}

int main(int argc, char* argv[]) {
    // === MUST RUN FIRST ===
    early_hardening();

    bool serviceMode = false;
    if (argc > 1 && std::string(argv[1]) == "--service") {
        serviceMode = true;
    }

    auto bus = std::make_unique<Venom::Core::VenomBus>();

    bus->registerModule(std::make_unique<Venom::Modules::SysctlModule>());

    if (serviceMode) {
        // Ring 3 – long-running scheduler
        Venom::Core::Scheduler scheduler(300);
        scheduler.start(*bus);
    } else {
        // Ring 1 – one-shot bootstrap
        bus->runAll();
    }

    std::cout << "[SUCCESS] White Venom engine operation completed.\n";
    return 0;
}

