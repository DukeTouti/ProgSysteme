#!/usr/bin/env bash
set -euo pipefail

echo "--- APPLYING COMMAND FIX FOR DHCP SERVER ---"

# 1. Ensure the directory and file exist
sudo ip netns exec ubuntu mkdir -p /var/lib/dhcp
sudo ip netns exec ubuntu touch /var/lib/dhcp/dhcpd.leases

# 2. Give full permissions (avoids Ubuntu permission errors)
sudo ip netns exec ubuntu chmod -R 777 /var/lib/dhcp

# 3. Kill any previous instance to free port 67
sudo ip netns exec ubuntu killall dhcpd 2>/dev/null || true

# 4. Start the server in background
# We specify the veth-ubuntu interface inside the namespace
sudo ip netns exec ubuntu /usr/sbin/dhcpd -4 -cf /etc/dhcp/dhcpd.conf veth-ubuntu &

echo "DHCP Server is now running in background!"
