#!/usr/bin/env bash
set -euo pipefail #Stop if a command returns an error

echo "--- STARTING NETWORK TOPOLOGY (UIR LAB) ---"

# --- CLEANUP, DEPENDENCIES CHECK & TUI ---
sudo ./CONF_WINDOW.sh
sudo ./CLEANUP.sh
sudo ./DEPENDENCIES.sh

# 1. FOUNDATIONS (L1/L2)
echo "[1/4] Creating namespaces and bridges..."
sudo ./CREATE_NAMESPACES.sh
sudo ./CREATE_L2_SWITCHES.sh

# 2. CABLING (Plugging in the network interfaces)
echo "[2/4] Connecting hosts and server to the switch..."
sudo ./PCs.sh
sudo ./UBUNTU_SERVER.sh

# 3. VLAN LOGIC (CRUCIAL: Configure the switch BEFORE services)
echo "[3/4] Configuring VLAN Logic (Self Untagged) and Gateways..."
sudo ./CREATE_VLANS.sh

# 4. TRANSIT & NAT
echo "[4/4] Configuring transit link and NAT..."
sudo ./CONNECT_CORE_TO_ROUTER.sh
sudo ./SETUP_NAT.sh

# 5. SERVICE CONFIGURATION AND STARTUP
echo "[5/4] Deploying configurations and starting services..."
# These scripts handle both setup AND service restart
sudo ./UBUNTU_SERV_SCRIPTS/SETUP_HTTPS.sh
sudo ./UBUNTU_SERV_SCRIPTS/SETUP_DNS.sh
sudo ./UBUNTU_SERV_SCRIPTS/SETUP_FTPS.sh
sudo ./UBUNTU_SERV_SCRIPTS/SETUP_DHCP.sh

# 6. FINALIZATION (Force-starting Daemons)
echo "[6/4] Finalizing network services..."
sleep 1

# --- Cleanup and Force Start Apache ---
sudo ip netns exec ubuntu service apache2 stop 2>/dev/null || true
sudo ip netns exec ubuntu rm -f /var/run/apache2/apache2.pid
sudo ip netns exec ubuntu bash -c 'source /etc/apache2/envvars && apache2 -k start'

# --- Cleanup and Force Start Bind9 ---
sudo ip netns exec ubuntu service bind9 stop 2>/dev/null || true
sudo ip netns exec ubuntu killall named 2>/dev/null || true
sudo ip netns exec ubuntu named -u bind -4

sudo ip netns exec ubuntu service vsftpd stop 2>/dev/null || true
sudo ip netns exec ubuntu killall vsftpd 2>/dev/null || true
sudo ip netns exec ubuntu vsftpd /etc/vsftpd.conf &

# --- DHCP Startup ---
sudo ip netns exec ubuntu /usr/sbin/dhcpd -4 -pf /run/dhcpd.pid -cf /etc/dhcp/dhcpd.conf veth-ubuntu &

# Relay agents
sudo ./UBUNTU_SERV_SCRIPTS/FIX_LEASE_RIGHT_DHCP_SERVER.sh
sudo ./UBUNTU_SERV_SCRIPTS/DHCP_RELAY_AGENT.sh

echo "[FIX] Finalizing Bridge Routing Logic..."
# These two lines allow the switch IP to "talk" to the VLANs
sudo ip netns exec sw-core bridge vlan add dev br-sw1 vid 10 self untagged
sudo ip netns exec sw-core bridge vlan add dev br-sw2 vid 40 self untagged # The server gains priority on br-sw2

# Force-wake IP forwarding
sudo ip netns exec sw-core sysctl -w net.ipv4.ip_forward=1

echo "-----------------------------------------------"
echo "      TOPOLOGY SUCCESSFULLY DEPLOYED           "
echo "   - Server: srv.uir.ma (172.17.4.10)          "
echo "-----------------------------------------------"

# Immediate diagnostic test
echo "Testing final connectivity..."
sudo ip netns exec pc-vlan10 ping -c 2 172.17.4.10
