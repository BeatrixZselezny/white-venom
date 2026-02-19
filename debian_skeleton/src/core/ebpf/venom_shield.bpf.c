#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <bpf/bpf_helpers.h>
#include <linux/in.h>

// Blacklist tábla az automatikus blokkoláshoz
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 1024);
    __type(key, __be32);
    __type(value, __u8);
} blacklist_map SEC(".maps");

// Statisztikai tábla a Dashboardhoz
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 2);
    __type(key, __u32);
    __type(value, __u64);
} stats_map SEC(".maps");

static __always_inline void update_stat(__u32 slot) {
    __u64 *count = bpf_map_lookup_elem(&stats_map, &slot);
    if (count) {
        __sync_fetch_and_add(count, 1);
    }
}

SEC("xdp")
int venom_router_guard(struct xdp_md *ctx) {
    void *data_end = (void *)(long)ctx->data_end;
    void *data = (void *)(long)ctx->data;

    struct ethhdr *eth = data;
    if ((void *)(eth + 1) > data_end) return XDP_PASS;

    if (eth->h_proto == __constant_htons(ETH_P_IP)) {
        struct iphdr *iph = (void *)(eth + 1);
        if ((void *)(iph + 1) > data_end) return XDP_PASS;

        update_stat(0); // Összes vizsgált IP csomag

        __u32 src_ip = iph->saddr;
        __u8 *blocked = bpf_map_lookup_elem(&blacklist_map, &src_ip);
        
        if (blocked && *blocked == 1) {
            update_stat(1); // Kernel szinten eldobott (Flushed Bit)
            return XDP_DROP;
        }
    }
    return XDP_PASS;
}

char _license[] SEC("license") = "GPL";
