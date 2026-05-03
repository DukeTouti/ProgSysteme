#!/usr/bin/env bash

echo "==================================================="
echo "LAUNCHING AL MASSAR NETWORK SERVICES"
echo "==================================================="

# ---------------------------------------------------------
# 1. SERVER ROUTING CONFIGURATION
# ---------------------------------------------------------
echo "[1/4] Configuring Return Routes for Ubuntu Server..."
# Permet au serveur de répondre aux clients via le Switch Core
sudo ip netns exec ubuntu ip route add 172.17.1.0/24 via 172.17.4.1 2>/dev/null || true
sudo ip netns exec ubuntu ip route add 172.17.2.0/24 via 172.17.4.1 2>/dev/null || true
sudo ip netns exec ubuntu ip route add 172.17.3.0/24 via 172.17.4.1 2>/dev/null || true

# ---------------------------------------------------------
# 2. CLIENT DNS ISOLATION
# ---------------------------------------------------------
echo "[2/4] Enforcing DNS Resolver for pc-vlan10..."
# Force le client à n'utiliser que ton serveur DNS Bind9
sudo ip netns exec pc-vlan10 sh -c 'rm -f /etc/resolv.conf && echo "nameserver 172.17.4.10" > /etc/resolv.conf'

# ---------------------------------------------------------
# 3. SECURE WEB SERVER (HTTPS) INITIALIZATION
# ---------------------------------------------------------
echo "[3/4] Starting Apache Web Server (SSL Enabled)..."
# Activation des modules et du site SSL
sudo ip netns exec ubuntu a2enmod ssl 2>/dev/null
sudo ip netns exec ubuntu a2ensite default-ssl 2>/dev/null

# --- FIX : Nettoyage pour éviter le conflit de PID ---
sudo killall -9 apache2 2>/dev/null || true
sudo rm -f /var/run/apache2/apache2.pid

# Démarrage propre dans le namespace
sudo ip netns exec ubuntu /bin/bash -c "source /etc/apache2/envvars && /usr/sbin/apache2 -k start"

# ---------------------------------------------------------
# 4. SECURE FTP SERVER (FTPS) INITIALIZATION
# ---------------------------------------------------------
echo "[4/4] Starting VSFTPD Service (Explicit TLS)..."
# On s'assure que vsftpd écoute de manière autonome
sudo sed -i 's/listen=NO/listen=YES/' /etc/vsftpd.conf 2>/dev/null
sudo sed -i 's/listen_ipv6=YES/#listen_ipv6=YES/' /etc/vsftpd.conf 2>/dev/null

# Arrêt des anciennes instances et démarrage
sudo ip netns exec ubuntu killall vsftpd 2>/dev/null || true
sudo ip netns exec ubuntu /usr/sbin/vsftpd /etc/vsftpd.conf &

echo "---------------------------------------------------"
echo " ALL SERVICES SUCCESSFULLY LAUNCHED AND SECURED"
echo "==================================================="
