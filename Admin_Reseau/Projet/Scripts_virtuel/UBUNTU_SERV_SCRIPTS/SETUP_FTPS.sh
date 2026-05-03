#!/usr/bin/env bash
set -euo pipefail

echo "--- CONFIGURING FTPS ON UBUNTU SERVER ---"

# 1. Create the test user inside the namespace (if not already present)
sudo ip netns exec ubuntu id -u testuser &>/dev/null || \
sudo ip netns exec ubuntu useradd -m -s /bin/bash testuser
sudo ip netns exec ubuntu sh -c 'echo "testuser:123" | chpasswd'

# 2. Configure vsftpd
cat <<'EOF' | ip netns exec ubuntu tee /etc/vsftpd.conf
# Basic configuration
listen=YES                      # Run as a standalone daemon
listen_ipv6=NO                  # Disable IPv6, use IPv4 only
listen_address=172.17.4.10      # Bind to the Ubuntu Server IP
anonymous_enable=NO             # Disable anonymous login for security
local_enable=YES                # Allow users from /etc/passwd to log in
write_enable=YES                # Allow uploading and modifying files
local_umask=022                 # Set default permissions for new files
dirmessage_enable=YES           # Show directory messages to users
use_localtime=YES               # Use server time for file logs
xferlog_enable=YES              # Enable logging of all transfers
connect_from_port_20=YES        # Use port 20 for data connections

# SSL/TLS CONFIGURATION
ssl_enable=YES                  # Enable SSL/TLS encryption for the server
allow_anon_ssl=NO               # Reject encrypted connections for anonymous users
force_local_data_ssl=YES        # Mandatory encryption for all data transfers
force_local_logins_ssl=YES      # Mandatory encryption for sending passwords
ssl_tlsv1=YES                   # Allow TLS v1.0 (standard for secure FTP)
ssl_sslv2=NO                    # Disable old/insecure SSL v2
ssl_sslv3=NO                    # Disable old/insecure SSL v3

# Paths to certificates
rsa_cert_file=/etc/ssl/certs/apache-selfsigned.crt       # Public certificate location
rsa_private_key_file=/etc/ssl/private/apache-selfsigned.key # Private key location

# PASSIVE MODE (Required for firewall/VLAN traversal)
pasv_enable=YES                 # Enable passive mode for easier routing
pasv_min_port=40000             # Minimum port for data transfer
pasv_max_port=40100             # Maximum port for data transfer
pasv_address=172.17.4.10        # Public IP to report to clients
EOF

echo "FTPS Configuration deployed."
