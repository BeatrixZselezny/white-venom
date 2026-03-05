#!/bin/bash
# ip6tables-router.sh

LAN_IF="wlan0"
WAN_IF="tun0"     # vagy proton0, wg0 stb.

ip6tables -F
ip6tables -X

# alap politikák
ip6tables -P INPUT DROP
ip6tables -P FORWARD DROP
ip6tables -P OUTPUT ACCEPT

# loopback
ip6tables -A INPUT -i lo -j ACCEPT

# engedjük az established kapcsolatokat
ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ip6tables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ICMPv6 szükséges típusok (NDP, RA, RS, Echo)
ip6tables -A INPUT -p ipv6-icmp --icmpv6-type 133 -j ACCEPT   # Router Solicitation
ip6tables -A INPUT -p ipv6-icmp --icmpv6-type 134 -j ACCEPT   # Router Advertisement
ip6tables -A INPUT -p ipv6-icmp --icmpv6-type 135 -j ACCEPT   # Neighbor Solicitation
ip6tables -A INPUT -p ipv6-icmp --icmpv6-type 136 -j ACCEPT   # Neighbor Advertisement
ip6tables -A INPUT -p ipv6-icmp --icmpv6-type 128 -j ACCEPT   # Echo Request

# Multicast féreg-ellenes DROP
ip6tables -A INPUT -d ff02::/16 -j DROP

# engedjük a LAN -> WAN forwardot
ip6tables -A FORWARD -i $LAN_IF -o $WAN_IF -j ACCEPT

# WAN -> LAN csak established kapcsolatok
ip6tables -A FORWARD -i $WAN_IF -o $LAN_IF -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

