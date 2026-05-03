#!/usr/bin/env bash
set -euo pipefail

echo "--- CONFIGURING VLANs AND GATEWAYS ON SW-CORE ---"

# Enable VLAN filtering on bridges
ip netns exec sw-core ip link set dev br-sw1 type bridge vlan_filtering 1
ip netns exec sw-core ip link set dev br-sw2 type bridge vlan_filtering 1

# FIX: 'self untagged' is required on the bridge CPU port.
# Without 'untagged', VLAN frames arrive tagged to the kernel IP stack
# which silently ignores them — ARP FAILED, ping "Destination Host Unreachable".
ip netns exec sw-core bridge vlan add dev br-sw1 vid 10 self untagged
ip netns exec sw-core bridge vlan add dev br-sw1 vid 20 self untagged
ip netns exec sw-core bridge vlan add dev br-sw2 vid 30 self untagged
ip netns exec sw-core bridge vlan add dev br-sw2 vid 40 self untagged

# Assign gateway IPs (SVI)
ip netns exec sw-core ip addr add 172.17.1.1/24 dev br-sw1 2>/dev/null || true
ip netns exec sw-core ip addr add 172.17.3.1/24 dev br-sw2 2>/dev/null || true
ip netns exec sw-core ip addr add 172.17.4.1/24 dev br-sw2 2>/dev/null || true

ip netns exec sw-core ip link set br-sw1 up
ip netns exec sw-core ip link set br-sw2 up

# Enable internal IP forwarding on the switch
ip netns exec sw-core sysctl -w net.ipv4.ip_forward=1
