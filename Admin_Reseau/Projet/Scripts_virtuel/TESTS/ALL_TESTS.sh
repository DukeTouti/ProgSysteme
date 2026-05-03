#!/usr/bin/env bash

echo "--- STARTING NETWORK TESTS ---"

# 1. RESETTING IP STACK OF PC-VLAN10
echo "[1/4] Cleaning network interface veth-pc10..."
# On libère d'abord l'IP proprement
sudo ip netns exec pc-vlan10 dhclient -r veth-pc10 2>/dev/null || true
# On flush pour supprimer les routes résiduelles
sudo ip netns exec pc-vlan10 ip addr flush dev veth-pc10

echo "[1.1/4] Triggering DORA process (DHCP Discovery)..."
sudo ip netns exec pc-vlan10 dhclient -v veth-pc10 2>/dev/null || true
sleep 2 # Convergence time (STP & DHCP lease)

# 2. GETTING IP FROM DHCP SERVER
echo "[2/4] Testing Layer 3 Connectivity..."

# From pc-vlan10 to pc-vlan30
echo "[2.1/4] Testing Inter-VLAN Routing: pc-vlan10 to pc-vlan30..."
ip netns exec pc-vlan10 ping -c 2 172.17.3.10

# From pc-vlan10 to google servers using NAT
echo "[2.2/4] Testing WAN Egress: pc-vlan10 to Google Public DNS (NAT check)..."
ip netns exec pc-vlan10 ping -c 2 8.8.8.8

# 3. TESTING UBUNTU WEB-SERVER SERVICES
echo "[3/4] Testing Application Services (Ubuntu Server)..."

# Testing DNS
echo "[3.1/4] Validating DNS Resolution (Standard Query)..."
sudo ip netns exec pc-vlan10 nslookup uir.ma

echo "[3.2/4] Analyzing DNS Resource Records (Advanced Dig)..."
sudo ip netns exec pc-vlan10 dig uir.ma

# Testing HTTPS
echo "[3.3/4] Checking Web Server Response via HTTPS (Headless Curl)..."
sudo ip netns exec pc-vlan10 curl -k https://uir.ma

echo "[3.4/4] Launching TUI Browser for Visual Service Validation..."
sudo ip netns exec pc-vlan10 links https://uir.ma

# Testing FTPS
echo "[3.5/4] Testing Secure File Transfer (Explicit FTPS over TLS)..."
sudo ip netns exec pc-vlan10 lftp -u testuser,123 -e "set ftp:ssl-force true; set ssl:verify-certificate no; ls; quit" ftps://uir.ma

# 5. END
echo "[4/4] ---- ALL NETWORK STACKS VALIDATED: END OF TEST ----"

