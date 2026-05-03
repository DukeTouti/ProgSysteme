#!/usr/bin/env bash
set -euo pipefail

# -- SETUP_DHCP.sh --

ip netns exec ubuntu mkdir -p /var/lib/dhcp
ip netns exec ubuntu touch /var/lib/dhcp/dhcpd.leases

# 1. Configure subnets for each VLAN
# We must not forgett to redirect the write operation inside the ubuntu namespace (and not the host)
cat <<EOF | ip netns exec ubuntu tee /etc/dhcp/dhcpd.conf
default-lease-time 600;
max-lease-time 7200;
authoritative;

# Subnet VLAN 10 (Purchasing)
subnet 172.17.1.0 netmask 255.255.255.0 {
  range 172.17.1.50 172.17.1.100;
  option routers 172.17.1.1;
  option domain-name-servers 172.17.4.10;
}

# Subnet VLAN 30 (HR)
subnet 172.17.3.0 netmask 255.255.255.0 {
  range 172.17.3.50 172.17.3.100;
  option routers 172.17.3.1;
  option domain-name-servers 172.17.4.10;
}

# Subnet local VLAN 40 (Servers)
subnet 172.17.4.0 netmask 255.255.255.0 {
  range 172.17.4.20 172.17.4.30;
  option routers 172.17.4.1;
}
EOF

# 2. RewStart the DHCP server
ip netns exec ubuntu service isc-dhcp-server restart

