#pragma once

namespace Venom::Core {

enum class PrivilegeLevel {
    None,
    UserNS,
    Root
};

struct PrivilegeContext {
    PrivilegeLevel level = PrivilegeLevel::None;

    bool needs_mount_ns  = false;
    bool needs_sysctl    = false;
    bool needs_fs_write  = false;
    bool needs_net_admin = false;

    const char* reason = nullptr;
};

} // namespace Venom::Core

