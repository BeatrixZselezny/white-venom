#ifndef CONFIGTEMPLATES_HPP
#define CONFIGTEMPLATES_HPP
#include <vector>
#include <string>

namespace VenomTemplates {
    const std::vector<std::string> BLACKLIST_CONTENT = {
        "blacklist usb-storage",
        "blacklist firewire-core",
        "blacklist thunderbolt",
        "install dccp /bin/true",
        "install sctp /bin/true"
    };

    const std::vector<std::string> MAKE_CONF_CONTENT = {
        "COMMON_FLAGS=\"-O2 -pipe -fstack-protector-strong -D_FORTIFY_SOURCE=2\"",
        "CHOST=\"x86_64-pc-linux-gnu\"",
        "USE=\"hardened nosuspnd no-python -unbound\"",
        "ACCEPT_LICENSE=\"*\""
    };
}
#endif
