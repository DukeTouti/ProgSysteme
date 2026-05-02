#!/usr/bin/env bash
set -euo pipefail

# -- CONNECT_CORE_TO_ROUTER.sh --

# 1. Create the transit veth pair (The virtual cable)
ip link add veth-sw2r type veth peer name veth-r2sw || true

# 2. Switch side configuration (sw-core)
ip link set veth-sw2r netns sw-core
ip netns exec sw-core sysctl -w net.ipv4.ip_forward=1
# Set the transit IP to 10.0.0.2
ip netns exec sw-core ip addr add 10.0.0.2/24 dev veth-sw2r 2>/dev/null || true
ip netns exec sw-core ip link set veth-sw2r up

# 3. Router side configuration (router)
ip link set veth-r2sw netns router
ip netns exec router sysctl -w net.ipv4.ip_forward=1
# Set the transit IP to 10.0.0.1 (This is the Switch's gateway to the world)
ip netns exec router ip addr add 10.0.0.1/24 dev veth-r2sw 2>/dev/null || true
ip netns exec router ip link set veth-r2sw up

# 4. Route for return traffic
# The router must know that all internal VLANs (172.17.0.0/16) are reached via the Switch
ip netns exec router ip route replace 172.17.0.0/16 via 10.0.0.2
