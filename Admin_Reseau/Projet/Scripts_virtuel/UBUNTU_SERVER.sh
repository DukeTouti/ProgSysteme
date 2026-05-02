#!/usr/bin/env bash
set -euo pipefail

# 1. Create the veth pair
ip link add veth-ubuntu type veth peer name veth-sw40
ip link set veth-sw40 netns sw-core

# 2. SWITCH SIDE: Attach to bridge br-sw2
ip netns exec sw-core ip link set veth-sw40 master br-sw2
ip netns exec sw-core ip link set veth-sw40 up
# Force VLAN 40
ip netns exec sw-core bridge vlan add dev veth-sw40 vid 40 pvid untagged

# 3. SERVER SIDE
ip link set veth-ubuntu netns ubuntu
ip netns exec ubuntu ip addr add 172.17.4.10/24 dev veth-ubuntu
ip netns exec ubuntu ip link set veth-ubuntu up
ip netns exec ubuntu ip link set lo up
ip netns exec ubuntu ip route add default via 172.17.4.1
