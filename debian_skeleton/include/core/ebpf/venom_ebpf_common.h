#ifndef VENOM_EBPF_COMMON_H
#define VENOM_EBPF_COMMON_H

#include <linux/types.h>

struct router_identity {
    unsigned char mac[6];
    __u32 trust_level; 
};

#endif
