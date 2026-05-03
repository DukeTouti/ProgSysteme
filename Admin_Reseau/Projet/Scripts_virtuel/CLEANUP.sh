#!/usr/bin/env bash
set -euo pipefail # Stop if a command returns an error


echo "--- SYSTEM CLEANUP IN PROGRESS ---"

# 1. Kill background processes
sudo killall dhclient 2>/dev/null || true

# 2. Stop services on host to free ports
sudo service apache2 stop 2>/dev/null || true
sudo service bind9 stop 2>/dev/null || true

# 3. Delete Namespaces
sudo ip -all netns delete 2>/dev/null || true

# 4. Wipe Bridges and Veth orphans
for br in $(brctl show | awk 'NR>1 {print $1}'); do
    sudo ip link set "$br" down 2>/dev/null || true
    sudo brctl delbr "$br" 2>/dev/null || true
done
sudo ip link flush type veth 2>/dev/null || true

echo "--- SYSTEM IS CLEAN ---"
