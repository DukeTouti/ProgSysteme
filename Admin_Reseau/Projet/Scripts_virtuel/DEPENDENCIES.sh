#!/usr/bin/env bash
# --- DEPENDENCIES.sh (Universal Linux Edition) ---
set -euo pipefail

echo "--- PREPARING ENVIRONMENT & DEPENDENCIES ---"

# 1. Verification and Installation of missing packages
# ───────────────────────────────────────────────────
# Defining core networking and TUI tools
PACKAGES=(
  "apache2"        # Apache HTTP Server (HTTPS service)
  "dnsmasq"        # Lightweight DHCP and DNS forwarder
  "bind9"          # BIND9 Authoritative DNS server
  "dnsutils"       # Network utilities (includes 'dig' for DNS testing)
  "bridge-utils"   # Utilities for configuring the Linux Ethernet bridge
  "vlan"           # Support for 802.1Q VLAN tagging
  "iptables"       # IPv4 packet filtering and NAT (Masquerading)
  "whiptail"       # Displays user-friendly dialog boxes (TUI)
  "curl"           # Command-line tool for HTTP/HTTPS testing
  "links"          # Text-mode web browser for visual validation
  "vsftpd"         # Very Secure FTP Daemon (FTPS support)
  "lftp"           # Advanced FTP/FTPS client used in test scripts
  "net-tools"      # Networking toolkit (includes 'netstat' for troubleshooting)
  "psmisc"         # Process management utilities (includes 'fuser' to unlock ports)
  "iproute2"       # Networking engine (required for namespaces and routing)
  "tcpdump"        # Command-line packet analyzer for live troubleshooting
)

echo "[*] Checking system dependencies..."

# UNIVERSAL PACKAGE MANAGER DETECTION
# This block identifies if the system uses Debian (apt), Arch (pacman), or Fedora (dnf)
if [ -x "$(command -v apt-get)" ]; then
    INSTALL_CMD="sudo apt-get install -y"
    UPDATE_CMD="sudo apt-get update -y"
    CHECK_PKG="dpkg -s"
elif [ -x "$(command -v pacman)" ]; then
    INSTALL_CMD="sudo pacman -S --noconfirm"
    UPDATE_CMD="sudo pacman -Syu"
    CHECK_PKG="pacman -Qi"
elif [ -x "$(command -v dnf)" ]; then
    INSTALL_CMD="sudo dnf install -y"
    UPDATE_CMD="sudo dnf check-update || true"
    CHECK_PKG="rpm -q"
else
    echo "ERROR: No supported package manager found (apt, pacman, dnf)."
    exit 1
fi

for pkg in "${PACKAGES[@]}"; do
    # Check if the package is already installed using the detected manager
    if ! $CHECK_PKG "$pkg" >/dev/null 2>&1; then
        echo "  [!] $pkg is missing. Installing..."
        # Update repositories before first installation
        $UPDATE_CMD > /dev/null 2>&1
        $INSTALL_CMD "$pkg" > /dev/null
        echo "  [+] $pkg installed successfully."
    else
        echo "  [OK] $pkg is already installed."
    fi
done

# 2. Remove all previous network configurations
# ───────────────────────────────────────────────────
echo "Cleaning up existing namespaces..."
# Ensuring a fresh start by deleting all existing network namespaces
sudo ip -all netns delete 2>/dev/null || true

# 3. Stop services that might be running on the host
# ───────────────────────────────────────────────────
echo "Stopping local services to avoid port conflicts..."
# We stop services on the host to free up ports (80, 443, 53) for the namespaces
sudo service apache2 stop 2>/dev/null || true
sudo service dnsmasq stop 2>/dev/null || true
sudo service bind9 stop 2>/dev/null || true

# Avoid lease related problems
echo "Cleaning up old DHCP clients..."
sudo killall dhclient 2>/dev/null || true

# 4. Final Directory Check
# ───────────────────────────────────────────────────
# Critical check to ensure the service logic sub-folder exists
if [ ! -d "UBUNTU_SERV_SCRIPTS" ]; then
    echo "ERROR: Directory UBUNTU_SERV_SCRIPTS not found!"
    exit 1
fi

echo "--- Environment is clean, dependencies verified, and ready. ---"
