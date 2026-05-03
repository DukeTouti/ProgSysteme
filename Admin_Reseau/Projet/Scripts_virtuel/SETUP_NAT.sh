#!/usr/bin/env bash
set -euo pipefail

echo "--- FINALIZING NAT & INTERNET ACCESS ---"

WAN_IF=$(ip route | grep default | awk '{print $5}' | head -n1)
echo "Detected WAN interface: $WAN_IF"

# -------------------------------------------------------
# ARCHITECTURE: veth host <-> router
# The router namespace has no direct access to WAN —
# we create a dedicated host<->router link, MASQUERADE
# is done on the host side (the only one connected to the real network).
# -------------------------------------------------------

# 1. Transit veth host <-> router
ip link add veth-host-wan type veth peer name veth-router-wan 2>/dev/null || true
ip link set veth-router-wan netns router 2>/dev/null || true

# 2. IPs on the transit link
ip addr replace 192.168.99.1/30 dev veth-host-wan
ip link set veth-host-wan up
ip netns exec router ip addr replace 192.168.99.2/30 dev veth-router-wan
ip netns exec router ip link set veth-router-wan up

# 3. Default route of the router namespace towards the host
ip netns exec router ip route replace default via 192.168.99.1

# 4. Enable ip_forward on all relevant namespaces
sysctl -w net.ipv4.ip_forward=1
ip netns exec router  sysctl -w net.ipv4.ip_forward=1
ip netns exec sw-core sysctl -w net.ipv4.ip_forward=1

# 5. Masquerade on the host — without source restriction
iptables -t nat -C POSTROUTING -o "$WAN_IF" -j MASQUERADE 2>/dev/null \
    || iptables -t nat -A POSTROUTING -o "$WAN_IF" -j MASQUERADE

# 6. FIX: INSERT at position 1 — libvirt/KVM rules are appended
# and block traffic at the end of the FORWARD chain.
# -I inserts before them, -A appends after (useless in this VM environment).
iptables -I FORWARD 1 -i veth-host-wan -o "$WAN_IF" -j ACCEPT
iptables -I FORWARD 1 -i "$WAN_IF" -o veth-host-wan \
    -m state --state RELATED,ESTABLISHED -j ACCEPT

# 7. Internal routes
ip netns exec router ip route replace 172.17.0.0/16 via 10.0.0.2
ip netns exec sw-core ip route replace default via 10.0.0.1

# Remove the old route to avoid the "File exists" error if the script is rerun
sudo ip route del 172.17.0.0/16 2>/dev/null || true

# Add the route via the WAN IP of our 'router' namespace
sudo ip route add 172.17.0.0/16 via 192.168.99.2

echo "NAT configured. Path: VLAN -> sw-core -> router -> host -> $WAN_IF"

