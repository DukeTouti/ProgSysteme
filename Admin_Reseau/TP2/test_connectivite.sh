#!/bin/bash
# =============================================================================
# TP2 - Script de tests DHCP + vérifications réseau
# =============================================================================

VERT="\e[32m"; ROUGE="\e[31m"; JAUNE="\e[33m"; BLEU="\e[34m"; CYAN="\e[36m"; RESET="\e[0m"
ok()    { echo -e "  ${VERT}[SUCCÈS]${RESET} $1"; }
fail()  { echo -e "  ${ROUGE}[ÉCHEC]${RESET}  $1 ${JAUNE}(voir note)${RESET}"; }
info()  { echo -e "  ${BLEU}[INFO]${RESET}   $1"; }
titre() { echo -e "\n${BLEU}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
          echo -e "${BLEU}  $1${RESET}"
          echo -e "${BLEU}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; }

ping_test() {
    local ns="$1" dest="$2" label="$3"
    if sudo ip netns exec "$ns" ping -4 -c 2 -W 2 "$dest" &>/dev/null; then
        ok "$label"
        return 0
    else
        fail "$label"
        return 1
    fi
}

echo ""
echo -e "${JAUNE}  TP2 — Tests DHCP + connectivité réseau virtuel${RESET}"
echo -e "${JAUNE}  $(date '+%d/%m/%Y %H:%M:%S')${RESET}"

# ─── SCÉNARIO 1 : Existence des namespaces ────────────────────────────────────
titre "SCÉNARIO 1 : Existence des namespaces (TP1 + DHCP_SERVER)"
echo ""
sudo ip netns list
echo ""
for ns in PC1 PC2 PC3 PC4 PC5 PC6 SW1 SW2 GATEWAY ISP DHCP_SERVER; do
    if sudo ip netns list | grep -q "^${ns}"; then
        ok "Namespace $ns présent"
    else
        fail "Namespace $ns MANQUANT"
    fi
done

# ─── SCÉNARIO 2 : Service DHCP actif ─────────────────────────────────────────
titre "SCÉNARIO 2 : Service dnsmasq en cours d'exécution"
echo ""
if sudo ip netns exec DHCP_SERVER ps aux 2>/dev/null | grep -q '[d]nsmasq'; then
    ok "dnsmasq tourne dans DHCP_SERVER"
    sudo ip netns exec DHCP_SERVER ps aux 2>/dev/null | grep '[d]nsmasq' | sed 's/^/    /'
else
    fail "dnsmasq NON actif dans DHCP_SERVER"
fi

# ─── SCÉNARIO 3 : Configuration IP du serveur DHCP ───────────────────────────
titre "SCÉNARIO 3 : Configuration IP du serveur DHCP"
echo ""
printf "  %-15s %-20s %s\n" "Namespace" "Interface" "Adresse IP"
printf "  %-15s %-20s %s\n" "──────────────" "───────────────────" "──────────────────"

for iface in dhcp1 dhcp2; do
    ip=$(sudo ip netns exec DHCP_SERVER ip addr show "$iface" 2>/dev/null | grep -oP 'inet \K[\d./]+')
    printf "  %-15s %-20s %s\n" "DHCP_SERVER" "$iface" "${ip:-(non configurée)}"
done

# ─── SCÉNARIO 4 : Interfaces DHCP des clients UP ─────────────────────────────
titre "SCÉNARIO 4 : Interfaces DHCP des clients (dhcp_pc1, dhcp_pc2)"
echo ""
for ns in PC1 PC2; do
    iface="dhcp_pc$(echo $ns | tr -d 'PC')"
    STATE=$(sudo ip netns exec "$ns" ip link show "$iface" 2>/dev/null | grep -oP 'state \K\w+')
    IP=$(sudo ip netns exec "$ns" ip addr show "$iface" 2>/dev/null | grep -oP 'inet \K[\d./]+')
    if [ -n "$IP" ]; then
        ok "$ns / $iface : $IP (état: ${STATE:-?})"
    else
        fail "$ns / $iface : aucune adresse IP (état: ${STATE:-non trouvée})"
    fi
done

# ─── SCÉNARIO 5 : Adresses IP attribuées par DHCP ────────────────────────────
titre "SCÉNARIO 5 : Adresses IP obtenues par DHCP"
echo ""
printf "  %-8s %-20s %-18s %s\n" "Client" "Interface" "Adresse IP" "Dans le pool ?"
printf "  %-8s %-20s %-18s %s\n" "──────" "───────────────────" "────────────────" "─────────────"

for ns_num in 1 2; do
    ns="PC${ns_num}"
    iface="dhcp_pc${ns_num}"
    ip=$(sudo ip netns exec "$ns" ip addr show "$iface" 2>/dev/null | grep -oP 'inet \K[\d.]+')
    network="192.168.1${ns_num}0"
    
    if [ -n "$ip" ]; then
        # Vérification que l'IP est dans le pool (50-100)
        last_octet=$(echo "$ip" | cut -d. -f4)
        if [ "$last_octet" -ge 50 ] && [ "$last_octet" -le 100 ] 2>/dev/null; then
            pool_ok="${VERT}OUI (pool .50-.100)${RESET}"
        else
            pool_ok="${ROUGE}NON (hors pool)${RESET}"
        fi
        printf "  %-8s %-20s %-18s " "$ns" "$iface" "$ip/24"
        echo -e "$pool_ok"
    else
        printf "  %-8s %-20s %-18s " "$ns" "$iface" "(aucune)"
        echo -e "${ROUGE}NON ATTRIBUÉE${RESET}"
    fi
done

# ─── SCÉNARIO 6 : Fichiers de baux DHCP ──────────────────────────────────────
titre "SCÉNARIO 6 : Fichiers de baux DHCP (leases)"
echo ""
info "Baux sur le serveur DHCP (/var/lib/misc/dnsmasq.leases) :"
LEASES=$(sudo ip netns exec DHCP_SERVER cat /var/lib/misc/dnsmasq.leases 2>/dev/null)
if [ -n "$LEASES" ]; then
    echo "$LEASES" | while read -r line; do
        expiry=$(echo "$line" | awk '{print $1}')
        mac=$(echo "$line"   | awk '{print $2}')
        ip=$(echo "$line"    | awk '{print $3}')
        host=$(echo "$line"  | awk '{print $4}')
        echo -e "    IP: ${VERT}$ip${RESET}  MAC: $mac  Hôte: $host"
    done
else
    fail "Aucun bail trouvé — vérifiez que dnsmasq tourne et que dhclient a été lancé"
fi

echo ""
info "Baux dhclient sur PC1 :"
sudo ip netns exec PC1 cat /var/lib/dhcp/dhclient.leases 2>/dev/null | \
    grep -E "(fixed-address|option routers|expire)" | sed 's/^/    /' || \
    echo "    (fichier de bail introuvable)"

echo ""
info "Baux dhclient sur PC2 :"
sudo ip netns exec PC2 cat /var/lib/dhcp/dhclient.leases 2>/dev/null | \
    grep -E "(fixed-address|option routers|expire)" | sed 's/^/    /' || \
    echo "    (fichier de bail introuvable)"

# ─── SCÉNARIO 7 : Ping client -> serveur DHCP (passerelle) ───────────────────
titre "SCÉNARIO 7 : Connectivité client -> serveur DHCP (passerelle)"
echo ""
ping_test PC1 192.168.10.1 "PC1 -> DHCP_SERVER/passerelle LAN1 (192.168.10.1)"
ping_test PC2 192.168.20.1 "PC2 -> DHCP_SERVER/passerelle LAN2 (192.168.20.1)"

# ─── SCÉNARIO 8 : Connectivité TP0 toujours opérationnelle ───────────────────
titre "SCÉNARIO 8 : Connectivité TP0 toujours opérationnelle"
echo ""
info "LAN1 — interfaces statiques (veth-PCx-pc) :"
ping_test PC3 192.168.10.11 "PC3 -> PC1 statique (192.168.10.11 via LAN1)"  2>/dev/null || true
ping_test PC5 192.168.10.10 "PC5 -> PC1 statique (192.168.10.10 via LAN1)"  2>/dev/null || true

echo ""
info "LAN2 — interfaces statiques (veth-PCx-pc) :"
ping_test PC4 192.168.20.10 "PC4 -> PC2 statique (192.168.20.10 via LAN2)"  2>/dev/null || true
ping_test PC6 192.168.20.10 "PC6 -> PC2 statique (192.168.20.10 via LAN2)"  2>/dev/null || true

# ─── SCÉNARIO 9 : Routes par défaut sur PC1 et PC2 ───────────────────────────
titre "SCÉNARIO 9 : Tables de routage de PC1 et PC2 (routes DHCP)"
echo ""
for ns in PC1 PC2; do
    echo -e "  ${JAUNE}$ns :${RESET}"
    sudo ip netns exec "$ns" ip route 2>/dev/null | sed 's/^/    /' || echo "    (vide)"
done

# ─── DÉTECTION DU CLIENT DHCP ────────────────────────────────────────────────
DHCP_CLIENT=""
for candidate in dhclient dhcpcd udhcpc; do
    if command -v "$candidate" &>/dev/null; then
        DHCP_CLIENT="$candidate"
        break
    fi
done

dhcp_release() {
    local ns="$1" iface="$2"
    case "$DHCP_CLIENT" in
        dhclient) sudo ip netns exec "$ns" dhclient -r "$iface" 2>/dev/null || true ;;
        dhcpcd)   sudo ip netns exec "$ns" dhcpcd -k "$iface" 2>/dev/null || true ;;
        udhcpc)   sudo ip netns exec "$ns" ip addr flush dev "$iface" 2>/dev/null || true ;;
        *)        sudo ip netns exec "$ns" ip addr flush dev "$iface" 2>/dev/null || true ;;
    esac
}

dhcp_request() {
    local ns="$1" iface="$2"
    case "$DHCP_CLIENT" in
        dhclient) sudo ip netns exec "$ns" dhclient "$iface" 2>/dev/null || true ;;
        dhcpcd)   sudo ip netns exec "$ns" dhcpcd "$iface" 2>/dev/null || true ;;
        udhcpc)   sudo ip netns exec "$ns" udhcpc -i "$iface" -n -q 2>/dev/null || true ;;
        *)        warn "Aucun client DHCP trouvé — skip" ;;
    esac
}

# ─── SCÉNARIO 10 : Renouvellement et libération du bail ──────────────────────
titre "SCÉNARIO 10 : Test renouvellement / libération de bail DHCP"
echo ""

if [ -z "$DHCP_CLIENT" ]; then
    info "Aucun client DHCP (dhclient/dhcpcd/udhcpc) détecté — scénario ignoré"
    info "Installez un client : sudo apt install isc-dhcp-client  OU  sudo apt install dhcpcd5"
else
    info "Client DHCP utilisé : $DHCP_CLIENT"
    echo ""
    info "Adresse actuelle de PC1 (avant libération) :"
    BEFORE=$(sudo ip netns exec PC1 ip addr show dhcp_pc1 2>/dev/null | grep -oP 'inet \K[\d./]+')
    echo -e "    ${VERT}${BEFORE:-(aucune)}${RESET}"

    echo ""
    info "Libération du bail PC1..."
    dhcp_release PC1 dhcp_pc1
    sudo ip netns exec PC1 ip addr flush dev dhcp_pc1 2>/dev/null || true
    sleep 1

    IP_AFTER_RELEASE=$(sudo ip netns exec PC1 ip addr show dhcp_pc1 2>/dev/null | grep -oP 'inet \K[\d./]+')
    if [ -z "$IP_AFTER_RELEASE" ]; then
        ok "Bail libéré — PC1 n'a plus d'adresse IP sur dhcp_pc1"
    else
        echo -e "  ${ROUGE}[INATTENDU]${RESET} PC1 a encore l'IP $IP_AFTER_RELEASE après libération"
    fi

    echo ""
    info "Renouvellement du bail PC1..."
    dhcp_request PC1 dhcp_pc1
    sleep 2

    IP_RENEWED=$(sudo ip netns exec PC1 ip addr show dhcp_pc1 2>/dev/null | grep -oP 'inet \K[\d./]+')
    if [ -n "$IP_RENEWED" ]; then
        ok "Bail renouvelé — PC1 a obtenu : $IP_RENEWED"
    else
        fail "Aucune adresse obtenue après renouvellement"
    fi
fi

# ─── SCÉNARIO 11 : Capture DHCP DORA (optionnel si tcpdump dispo) ────────────
titre "SCÉNARIO 11 : Observation échange DHCP DORA"
echo ""

if command -v tcpdump &>/dev/null || sudo ip netns exec PC1 which tcpdump &>/dev/null 2>&1; then
    info "Capture tcpdump DHCP sur PC1 (5 secondes)..."

    # Flush l'IP de PC1 pour forcer un vrai DISCOVER
    dhcp_release PC1 dhcp_pc1
    sudo ip netns exec PC1 ip addr flush dev dhcp_pc1 2>/dev/null || true

    # Capture en arrière-plan
    sudo ip netns exec PC1 tcpdump -nni dhcp_pc1 -c 8 port 67 or port 68 \
        2>/dev/null > /tmp/dhcp_capture.txt &
    PID_TCPDUMP=$!
    sleep 1

    # Déclencher l'échange DORA
    dhcp_request PC1 dhcp_pc1 &
    sleep 4
    sudo kill $PID_TCPDUMP 2>/dev/null || true
    wait $PID_TCPDUMP 2>/dev/null || true

    echo ""
    echo -e "  Paquets DHCP capturés sur PC1/dhcp_pc1 :"
    echo -e "  ${JAUNE}──────────────────────────────────────────${RESET}"
    if [ -s /tmp/dhcp_capture.txt ]; then
        cat /tmp/dhcp_capture.txt | sed 's/^/    /'
    else
        echo "    (aucune capture — tcpdump non disponible dans le namespace)"
    fi
    echo ""
    echo -e "  ${CYAN}Séquence DORA attendue :${RESET}"
    echo "    1. DISCOVER -> broadcast (255.255.255.255, port 67)"
    echo "    2. OFFER    <- serveur (IP proposée depuis le pool)"
    echo "    3. REQUEST  -> broadcast (confirmation de l'offre)"
    echo "    4. ACK      <- serveur (attribution confirmée)"
else
    info "tcpdump non disponible — capture ignorée"
    echo -e "  ${CYAN}Séquence DORA rappel :${RESET}"
    echo "    DISCOVER -> OFFER -> REQUEST -> ACK"
fi

# ─── RÉSUMÉ FINAL ─────────────────────────────────────────────────────────────
titre "RÉSUMÉ — TP2 DHCP"
echo ""
echo -e "  ${JAUNE}Scénario 1${RESET}  — Namespaces        : TP1 + DHCP_SERVER"
echo -e "  ${JAUNE}Scénario 2${RESET}  — dnsmasq actif     : service DHCP opérationnel"
echo -e "  ${JAUNE}Scénario 3${RESET}  — IP serveur DHCP   : dhcp1=10.1 dhcp2=20.1"
echo -e "  ${JAUNE}Scénario 4${RESET}  — Interfaces UP     : dhcp_pc1 et dhcp_pc2"
echo -e "  ${JAUNE}Scénario 5${RESET}  — Attribution DHCP  : IP dans pool .50-.100"
echo -e "  ${JAUNE}Scénario 6${RESET}  — Fichiers de baux  : dnsmasq.leases + dhclient.leases"
echo -e "  ${JAUNE}Scénario 7${RESET}  — Ping passerelle   : PC1->10.1 PC2->20.1"
echo -e "  ${JAUNE}Scénario 8${RESET}  — TP1 intact        : connectivité statique préservée"
echo -e "  ${JAUNE}Scénario 9${RESET}  — Tables de routage : route par défaut via DHCP"
echo -e "  ${JAUNE}Scénario 10${RESET} — Cycle bail DHCP   : libération + renouvellement"
echo -e "  ${JAUNE}Scénario 11${RESET} — Échange DORA       : DISCOVER/OFFER/REQUEST/ACK"
echo ""
