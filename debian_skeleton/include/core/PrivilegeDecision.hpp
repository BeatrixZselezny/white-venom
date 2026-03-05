#pragma once
#include <vector>
#include "PrivilegeContext.hpp"

namespace Venom::Core {

PrivilegeContext mergeContexts(
    const std::vector<PrivilegeContext>& contexts
);

} // namespace Venom::Core

