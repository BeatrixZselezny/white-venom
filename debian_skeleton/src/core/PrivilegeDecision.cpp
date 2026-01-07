#include "core/PrivilegeDecision.hpp"

namespace Venom::Core {

PrivilegeContext mergeContexts(
    const std::vector<PrivilegeContext>& contexts
) {
    PrivilegeContext result;

    for (const auto& ctx : contexts) {
        if (ctx.level > result.level)
            result.level = ctx.level;

        result.needs_mount_ns  |= ctx.needs_mount_ns;
        result.needs_sysctl    |= ctx.needs_sysctl;
        result.needs_fs_write  |= ctx.needs_fs_write;
        result.needs_net_admin |= ctx.needs_net_admin;
    }

    return result;
}

} // namespace Venom::Core

