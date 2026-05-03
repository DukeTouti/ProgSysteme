#!/usr/bin/env bash
set -euo pipefail

# --- PC 1 : VLAN 10 (Purchasing) ---
ip link add veth-pc10 type veth peer name veth-sw10
ip link set veth-sw10 netns sw-core
ip netns exec sw-core ip link set veth-sw10 master br-sw1
ip netns exec sw-core ip link set veth-sw10 up
ip netns exec sw-core bridge vlan add dev veth-sw10 vid 10 pvid untagged

ip link set veth-pc10 netns pc-vlan10
ip netns exec pc-vlan10 ip addr add 172.17.1.10/24 dev veth-pc10
ip netns exec pc-vlan10 ip link set veth-pc10 up
ip netns exec pc-vlan10 ip route add default via 172.17.1.1

# --- PC 2 : VLAN 30 (HR) ---
ip link add veth-pc30 type veth peer name veth-sw30
ip link set veth-sw30 netns sw-core
ip netns exec sw-core ip link set veth-sw30 master br-sw2
ip netns exec sw-core ip link set veth-sw30 up
ip netns exec sw-core bridge vlan add dev veth-sw30 vid 30 pvid untagged

ip link set veth-pc30 netns pc-vlan30
ip netns exec pc-vlan30 ip addr add 172.17.3.10/24 dev veth-pc30
ip netns exec pc-vlan30 ip link set veth-pc30 up
ip netns exec pc-vlan30 ip route add default via 172.17.3.1

