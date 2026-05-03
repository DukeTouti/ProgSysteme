#!/bin/bash

echo "[*] Applying segmentation ACLs on sw-core..."

# 1. Allow local traffic (loopback)
sudo ip netns exec sw-core iptables -A FORWARD -i lo -j ACCEPT

# 2. Allow already established connections (responses to requests)
sudo ip netns exec sw-core iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# 3. INTER-VLAN RESTRICTIONS (VLANs 10, 20, 30 cannot communicate with each other)
# Block traffic coming from one client VLAN to another client VLAN
VLAN_CLIENTS=("172.17.1.0/24" "172.17.2.0/24" "172.17.3.0/24")

for src in "${VLAN_CLIENTS[@]}"; do
    for dst in "${VLAN_CLIENTS[@]}"; do
        if [ "$src" != "$dst" ]; then
            sudo ip netns exec sw-core iptables -A FORWARD -s "$src" -d "$dst" -j DROP
            echo "Blocked: $src -> $dst"
        fi
    done
done

# 4. PERMISSIONS TO SERVER & INTERNET
# By default, anything not blocked above will pass (VLAN 40 and Internet)
sudo ip netns exec sw-core iptables -P FORWARD ACCEPT

echo "ACLs successfully applied!"
