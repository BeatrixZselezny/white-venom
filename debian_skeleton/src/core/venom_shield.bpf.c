#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/pkt_cls.h>
#include <bpf/bpf_helpers.h>

/* * Ez a tábla (Map) tárolja a fehérlistás MAC címeket.
 * A C++ oldal (RawPacketProbe.cpp) ide fogja betölteni az engedélyezett routereket.
 */
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 16);
    __type(key, unsigned char[6]); // MAC cím
    __type(value, __u32);          // Trust level vagy státusz
} allowed_routers SEC(".maps");

SEC("classifier")
int venom_router_guard(struct __sk_buff *skb) {
    void *data_end = (void *)(long)skb->data_end;
    void *data = (void *)(long)skb->data;
    struct ethhdr *eth = data;

    // Boundary check (Kernel biztonság: nem nyúlhatunk túl a csomagon)
    if (data + sizeof(*eth) > data_end)
        return TC_ACT_OK;

    // Csak a bejövő forgalmat nézzük (opcionális szűrés)
    // Megnézzük, szerepel-e a forrás MAC a fehérlistánkban
    __u32 *trusted = bpf_map_lookup_elem(&allowed_routers, eth->h_source);

    if (trusted) {
        return TC_ACT_OK; // Ismert router, mehet tovább
    }

    // Ha nem ismerjük, és gyanús (pl. ICMPv6 RA csomag), itt dobhatnánk el, 
    // vagy küldhetünk jelzést a C++ busznak.
    return TC_ACT_OK; 
}

char _license[] SEC("license") = "GPL";
