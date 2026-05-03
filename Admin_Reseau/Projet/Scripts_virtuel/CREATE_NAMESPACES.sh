#!/usr/bin/env bash
set -euo pipefail #Stop if a command returns an error

for ns in router sw-core ubuntu pc-vlan10 pc-vlan30; do
    ip netns add $ns
done

for ns in router sw-core ubuntu pc-vlan10 pc-vlan30; do
    ip netns exec $ns ip link set lo up
done
