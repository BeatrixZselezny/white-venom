#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/pkt_cls.h>
#include <bpf/bpf_helpers.h>

/* * White-Venom eBPF Shield v1.0
 * Kernel-level Router Advertisement Filter
 */

struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 16);
    __type(key, unsigned char[6]); // Router MAC address
    __type(value, __u32);          // Trust flag
} allowed_routers SEC(".maps");

SEC("classifier")
int venom_router_guard(struct __sk_buff *skb) {
    void *data_end = (void *)(long)skb->data_end;
    void *data = (void *)(long)skb->data;
    struct ethhdr *eth = data;

    // Boundary check a kernel verifikátornak
    if (data + sizeof(*eth) > data_end)
        return TC_ACT_OK;

    // Itt nézzük meg, hogy a forrás MAC benne van-e a fehérlistában
    __u32 *trusted = bpf_map_lookup_elem(&allowed_routers, eth->h_source);

    if (trusted) {
        return TC_ACT_OK; // Ismert barát, mehet tovább
    }

    // Ha nem ismerjük, az eseményt a C++ motor fogja elkapni a Raw Socketen
    return TC_ACT_OK; 
}

char _license[] SEC("license") = "GPL";
