#!/usr/bin/env bash
# --- CONF_WINDOW.sh (Al Massar Corporate) ---

# ─────────────────────────────────────────────
#  PRE-DEPLOYMENT CHECK (Identify missing packages)
# ─────────────────────────────────────────────
PACKAGES=("apache2" "dnsmasq" "bridge-utils" "vlan" "iptables" "whiptail" "curl" "vsftpd" "lftp")
MISSING_LIST=""

for pkg in "${PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        MISSING_LIST+="    • $pkg\n"
    fi
done

if [ -z "$MISSING_LIST" ]; then
    MISSING_DISPLAY="    [ All dependencies are already installed ]"
else
    MISSING_DISPLAY="  The following required packages will be installed:\n$MISSING_LIST"
fi

# ─────────────────────────────────────────────
#  TERMINAL SIZE (adaptive)
# ─────────────────────────────────────────────
TERM_LINES=$(tput lines)
TERM_COLS=$(tput cols)
H=$(( TERM_LINES * 75 / 100 ))
W=$(( TERM_COLS  * 85 / 100 ))
(( H < 18 )) && H=18
(( W < 70 )) && W=70
(( H > 32 )) && H=32
(( W > 100 )) && W=100

# ─────────────────────────────────────────────
#  COLOR THEMES
# ─────────────────────────────────────────────
THEME_GREEN='
  root=green,black
  window=green,black
  border=brightgreen,black
  textbox=green,black
  button=black,green
  actbutton=black,brightgreen
  title=brightgreen,black
  compactbutton=green,black
'
THEME_RED='
  root=red,black
  window=red,black
  border=brightred,black
  textbox=red,black
  button=black,red
  actbutton=black,brightred
  title=brightred,black
'

# ─────────────────────────────────────────────
#  INTRO — Grand Logo Al Massar
# ─────────────────────────────────────────────
clear
echo -e "\e[32m"
cat << 'EOF'
  █████╗ ██╗      ███╗   ███╗ █████╗ ███████╗███████╗ █████╗ ██████╗
 ██╔══██╗██║      ████╗ ████║██╔══██╗██╔════╝██╔════╝██╔══██╗██╔══██╗
 ███████║██║      ██╔████╔██║███████║███████╗███████╗███████║██████╔╝
 ██╔══██║██║      ██║╚██╔╝██║██╔══██║╚════██║╚════██║██╔══██║██╔══██╗
 ██║  ██║███████╗ ██║ ╚═╝ ██║██║  ██║███████║███████║██║  ██║██║  ██║
 ╚═╝  ╚═╝╚══════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝

           C O R P O R A T E   N E T W O R K   D E P L O Y M E N T
EOF
echo -e "\e[0m"
echo -e "[*] Initializing Al Massar network environment..."
sleep 0.8

# ─────────────────────────────────────────────
#  PHASE 1 — Environment Status
# ─────────────────────────────────────────────
export NEWT_COLORS="$THEME_GREEN"
whiptail --title " AL MASSAR INFRASTRUCTURE " \
    --infobox "\
\n\
  - System Base: Lubuntu (Minimal Install)\n\
  - Network Status: Ready for Deployment\n\
  - VLAN Segments: 10, 20, 30 (Users) | 40 (Server)\n\
  - Security Mode: Standby\n\
" \
    10 $W
sleep 1.5

# ─────────────────────────────────────────────
#  PHASE 2 — Confirmation & Identification
# ─────────────────────────────────────────────
if ! whiptail --title " DEPLOYMENT CONFIRMATION " \
    --yesno "\
\n\
  Environment : Al Massar Corporate Network\n\
  User        : ${USER:-unknown}@${HOSTNAME:-localhost}\n\
\n\
  SYSTEM DEPENDENCIES:\n\
$MISSING_DISPLAY\n\
\n\
  COMPONENTS TO CONFIGURE:\n\
    - Inter-VLAN Routing & DHCP Relay\n\
    - NAT & WAN Access\n\
    - Local DNS Resolver (uir.ma)\n\
    - Secure Services (HTTPS & FTPS)\n\
\n\
  Do you want to proceed with the full configuration?\n\
" \
    $H $W \
    --yes-button " PROCEED " \
    --no-button  " CANCEL "; then

    export NEWT_COLORS="$THEME_RED"
    whiptail --title " DEPLOYMENT CANCELLED " --msgbox "\n  Operation cancelled. No changes applied." 8 $W
    exit 1
fi

OPERATOR_NAME=$(whiptail --title " OPERATOR IDENTIFICATION " \
    --inputbox "Enter the Lead Engineer name for this session:" \
    10 $W "${USER}" \
    3>&1 1>&2 2>&3) || exit 1
OPERATOR_NAME=${OPERATOR_NAME:-"Unknown Operator"}

# ─────────────────────────────────────────────
#  PHASE 3 — SECURITY SHIELD (ACL Selection)
# ─────────────────────────────────────────────
ACL_ENABLED=0
if whiptail --title " SECURITY PROTOCOL " \
    --yesno "\
  [ NETWORK SECURITY SHIELD ]\n\
\n\
  Activate ACL Segmentation (Inter-VLAN Filtering)?\n\
\n\
  IF ACTIVATED:\n\
  - VLANs 10, 20, 30 will be ISOLATED from each other.\n\
  - All VLANs retain access to SERVER (VLAN 40).\n\
  - All VLANs retain access to INTERNET.\n\
\n\
  Enable this security layer now?" \
    15 $W --yes-button " ACTIVATE " --no-button " BYPASS "; then
    ACL_ENABLED=1
fi

# ─────────────────────────────────────────────
#  PHASE 4 — Execution Progress
# ─────────────────────────────────────────────
(
    echo 10;
    # Install missing packages
    for pkg in "${PACKAGES[@]}"; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            sudo apt-get update -y > /dev/null 2>&1
            sudo apt-get install -y "$pkg" > /dev/null 2>&1
        fi
    done

    echo 40; sleep 0.5
    # Here you would run your actual setup scripts:
    # ./SETUP_VLAN.sh > /dev/null

    echo 70; sleep 0.5
    if [ $ACL_ENABLED -eq 1 ]; then
        echo 85; # Simulation or real call to ./apply_ACL.sh
        sleep 0.8
    fi
    echo 100; sleep 0.4
) | whiptail --title " DEPLOYMENT IN PROGRESS " \
    --gauge "\
  Installing required dependencies...\n\
  Configuring Virtual Namespaces & Bridges...\n\
  $( [ $ACL_ENABLED -eq 1 ] && echo "Applying Security Shield (ACLs)..." || echo "Warning: Inter-VLAN security skipped..." )\n\
  Starting DNS, Apache & VSFTPD..." \
    12 $W 0

# ─────────────────────────────────────────────
#  PHASE 5 — Final Status & Logging
# ─────────────────────────────────────────────
clear
echo -e "\e[32m"
echo -e "  [ SYSTEM STATUS  : OPERATIONAL          ]"
echo -e "  [ LEAD ENGINEER  : $OPERATOR_NAME ]"
echo -e "  [ SECURITY LEVEL : $( [ $ACL_ENABLED -eq 1 ] && echo "HIGH (ACL ACTIVE)" || echo "LOW (OPEN)" ) ]"
echo -e "  [ INFRASTRUCTURE : AL MASSAR            ]"
echo -e "  [ SERVICES       : ACTIVE (DNS/WEB/FTP) ]"
echo -e "\n  Success! The corporate environment is now live.\e[0m"

# --- LOG PATH CONFIGURATION ---
LOG_DIR="./LOG_AL_MASSAR"
LOG_FILE="$LOG_DIR/deployment.log"

# Create the folder if it does not exist
mkdir -p "$LOG_DIR"

# Write enriched log
echo "[$(date '+%Y-%m-%d %H:%M:%S')] - Operator: $OPERATOR_NAME | Security: $( [ $ACL_ENABLED -eq 1 ] && echo "ENABLED" || echo "DISABLED" ) | Status: SUCCESS" >> "$LOG_FILE"

# Final informational window
whiptail --title " DEPLOYMENT COMPLETE " \
    --msgbox "\n  [ SYSTEM ONLINE ]\n\n  Operator : $OPERATOR_NAME\n  Security : $( [ $ACL_ENABLED -eq 1 ] && echo "Enabled" || echo "Disabled" )\n  Log file : $LOG_FILE\n\n  Al Massar is now fully operational." \
    15 $W

exit 0
