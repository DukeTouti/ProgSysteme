#!/usr/bin/env bash
set -euo pipefail

# 1. Create bridges
ip netns exec sw-core ip link add br-sw1 type bridge
ip netns exec sw-core ip link add br-sw2 type bridge

# 2. DISABLE STP (Avoids the 30s wait)
ip netns exec sw-core brctl stp br-sw1 off 2>/dev/null || true
ip netns exec sw-core brctl stp br-sw2 off 2>/dev/null || true

# 3. Bring bridges up
ip netns exec sw-core ip link set br-sw1 up
ip netns exec sw-core ip link set br-sw2 up

echo "L2 bridges created and STP disabled."
