#ifndef CONFIGTEMPLATES_HPP
#define CONFIGTEMPLATES_HPP

#include <vector>
#include <string>

namespace VenomTemplates {
    extern const std::vector<std::string> SYSCTL_BOOTSTRAP_CONTENT;
    extern const std::vector<std::string> BLACKLIST_CONTENT;
    extern const std::string KERNEL_HARDENING_PARAMS;
    extern const std::vector<std::string> FSTAB_HARDENING_CONTENT;
    extern const std::vector<std::string> MAKE_CONF_CONTENT;
    extern const std::vector<std::string> CANARY_CONTENT;
}

#endif
