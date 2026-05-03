#!/usr/bin/env bash
set -euo pipefail

echo "--- STARTING DHCP RELAY ---"

# 1. Kill any previous relay instance
ip netns exec sw-core killall dhcrelay 2>/dev/null || true

# FIX: Do NOT assign IPs to veth-sw1 / veth-sw2.
# Those are access ports that already carry VLAN traffic to the PCs.
# Putting gateway IPs on them creates duplicate addresses with the bridge
# SVIs (br-sw1 / br-sw2) and causes undefined routing behaviour.
#
# The bridges br-sw1 (172.17.1.1) and br-sw2 (172.17.3.1) already have
# valid IPs from CREATE_VLANS.sh — dhcrelay can anchor on them directly.

# 2. Ensure VLAN 40 is reachable from sw-core (server-side bridge)
ip netns exec sw-core bridge vlan add dev br-sw2 vid 40 self 2>/dev/null || true

# 3. Start relay — listen on the SVI bridges, forward to Ubuntu server
# The & is intentional: dhcrelay blocks, we need the script to return
ip netns exec sw-core /usr/sbin/dhcrelay \
    -i br-sw1 \
    -i br-sw2 \
    172.17.4.10 &

echo "DHCP relay running on br-sw1 (VLAN10) and br-sw2 (VLAN30) -> 172.17.4.10"
