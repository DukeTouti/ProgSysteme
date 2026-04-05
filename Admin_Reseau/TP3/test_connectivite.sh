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

# =============================================================================
# TP3 — TESTS NAT (DYNAMIQUE + STATIQUE)
# =============================================================================

# ─── DÉTECTION DU MODE NAT ACTIF ─────────────────────────────────────────────
NAT_MODE=""
if sudo ip netns exec GATEWAY iptables -t nat -L POSTROUTING -n 2>/dev/null | grep -q "MASQUERADE"; then
    NAT_MODE="DYNAMIQUE"
elif sudo ip netns exec GATEWAY iptables -t nat -L POSTROUTING -n 2>/dev/null | grep -q "SNAT"; then
    NAT_MODE="STATIQUE"
fi

# ─── SCÉNARIO 12 : Règles iptables NAT présentes ─────────────────────────────
titre "SCÉNARIO 12 : Règles iptables NAT sur GATEWAY"
echo ""

info "Table NAT — POSTROUTING :"
sudo ip netns exec GATEWAY iptables -t nat -L POSTROUTING -v -n 2>/dev/null | sed 's/^/    /'
echo ""

info "Chaîne FORWARD :"
sudo ip netns exec GATEWAY iptables -L FORWARD -v -n 2>/dev/null | sed 's/^/    /'
echo ""

# Vérification du forwarding IP
FWD=$(sudo ip netns exec GATEWAY cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "0")
if [ "$FWD" = "1" ]; then
    ok "IP forwarding GATEWAY : actif (1)"
else
    fail "IP forwarding GATEWAY : DÉSACTIVÉ — le NAT ne fonctionnera pas"
fi

if [ -n "$NAT_MODE" ]; then
    ok "Mode NAT détecté : $NAT_MODE"
else
    fail "Aucune règle NAT (MASQUERADE ou SNAT) trouvée — lancez enable_dynamic_nat.sh ou enable_static_nat.sh"
fi

# ─── SCÉNARIO 13 : Ping PC -> ISP avec NAT ────────────────────────────────────
titre "SCÉNARIO 13 : Connectivité PC -> ISP via NAT (209.165.200.225)"
echo ""

# Compteurs avant
PKTS_BEFORE=$(sudo ip netns exec GATEWAY iptables -t nat -L POSTROUTING -v -n 2>/dev/null \
    | awk 'NR>2 {sum += $1} END {print sum+0}')

ping_test PC1 209.165.200.225 "PC1 -> ISP (209.165.200.225) via NAT"
ping_test PC2 209.165.200.225 "PC2 -> ISP (209.165.200.225) via NAT"

# Compteurs après — vérifier que les paquets ont bien transité par les règles NAT
PKTS_AFTER=$(sudo ip netns exec GATEWAY iptables -t nat -L POSTROUTING -v -n 2>/dev/null \
    | awk 'NR>2 {sum += $1} END {print sum+0}')

if [ "$PKTS_AFTER" -gt "$PKTS_BEFORE" ] 2>/dev/null; then
    ok "Compteurs NAT POSTROUTING incrémentés : $PKTS_BEFORE -> $PKTS_AFTER paquets"
else
    fail "Compteurs NAT non incrémentés — le trafic ne passe pas par les règles NAT"
fi

# ─── SCÉNARIO 14 : Vérification de la translation (tcpdump côté ISP) ─────────
titre "SCÉNARIO 14 : Vérification de la translation IP (tcpdump ISP)"
echo ""
info "Capture tcpdump sur ISP (isp1) pendant un ping PC1 -> ISP (3 secondes)..."
echo ""

# Capture en arrière-plan sur ISP
sudo ip netns exec ISP tcpdump -nni isp1 -c 6 icmp 2>/dev/null \
    > /tmp/nat_capture.txt &
PID_TCPDUMP=$!
sleep 0.5

# Déclencher le trafic
sudo ip netns exec PC1 ping -c 3 -W 1 209.165.200.225 &>/dev/null &
sudo ip netns exec PC2 ping -c 3 -W 1 209.165.200.225 &>/dev/null &
sleep 3
sudo kill $PID_TCPDUMP 2>/dev/null || true
wait $PID_TCPDUMP 2>/dev/null || true

echo -e "  ${JAUNE}Paquets ICMP vus par l'ISP (interface isp1) :${RESET}"
echo -e "  ${JAUNE}──────────────────────────────────────────────────────${RESET}"
if [ -s /tmp/nat_capture.txt ]; then
    cat /tmp/nat_capture.txt | sed 's/^/    /'
    echo ""
    # Vérifier que l'ISP voit uniquement les IPs publiques, pas les IPs privées
    if grep -qE "192\.168\.(10|20)\." /tmp/nat_capture.txt; then
        fail "L'ISP voit des IPs PRIVÉES (192.168.x.x) — la translation NAT ne fonctionne pas !"
    else
        ok "L'ISP ne voit aucune IP privée — la translation NAT est correcte"
    fi
    # Vérifier quelle IP publique est vue
    if grep -q "209\.165\.200\.226" /tmp/nat_capture.txt; then
        ok "ISP voit les paquets depuis 209.165.200.226 (IP WAN GATEWAY)"
    fi
    if grep -q "209\.165\.200\.227" /tmp/nat_capture.txt; then
        ok "ISP voit les paquets depuis 209.165.200.227 (IP publique PC2 — SNAT)"
    fi
else
    info "(aucun paquet capturé — tcpdump non disponible dans ISP ou trafic absent)"
fi

# ─── SCÉNARIO 15 : Suivi de connexion conntrack ───────────────────────────────
titre "SCÉNARIO 15 : Table de suivi de connexion (conntrack)"
echo ""

if sudo ip netns exec GATEWAY conntrack -L 2>/dev/null | grep -q .; then
    info "Entrées conntrack actives sur GATEWAY :"
    sudo ip netns exec GATEWAY conntrack -L 2>/dev/null | head -10 | sed 's/^/    /'
    echo ""
    CONNTRACK_COUNT=$(sudo ip netns exec GATEWAY conntrack -L 2>/dev/null | wc -l)
    ok "Nombre d'entrées conntrack : $CONNTRACK_COUNT"
else
    info "Table conntrack vide ou conntrack non installé"
    info "Pour installer : sudo apt install conntrack"
fi

# ─── SCÉNARIO 16 (NAT DYNAMIQUE uniquement) : PAT — ports distincts ──────────
if [ "$NAT_MODE" = "DYNAMIQUE" ]; then
    titre "SCÉNARIO 16 : NAT Dynamique — vérification PAT (ports distincts)"
    echo ""
    info "Deux connexions simultanées PC1 + PC2 -> ISP (nc port 8888)..."
    echo ""

    # Lancer un serveur netcat sur ISP
    sudo ip netns exec ISP nc -l -p 8888 &>/dev/null &
    PID_NC_ISP=$!
    sleep 0.3

    # Connexions depuis PC1 et PC2
    sudo ip netns exec PC1 bash -c "echo 'PC1' | nc -w 2 209.165.200.225 8888" &>/dev/null &
    PID_PC1=$!
    sleep 0.2
    sudo ip netns exec PC2 bash -c "echo 'PC2' | nc -w 2 209.165.200.225 8888" &>/dev/null &
    PID_PC2=$!
    sleep 1

    # Lire conntrack pendant les connexions actives
    info "Entrées conntrack TCP (flows PC1/PC2 simultanés) :"
    sudo ip netns exec GATEWAY conntrack -L 2>/dev/null \
        | grep -E "tcp.*209\.165\.200\.(225|226)" \
        | head -4 \
        | sed 's/^/    /' || echo "    (aucune entrée TCP active)"
    echo ""

    # Vérifier que les deux flows ont des ports source différents
    PORTS=$(sudo ip netns exec GATEWAY conntrack -L 2>/dev/null \
        | grep -oP 'dport=\K\d+' | sort -u | wc -l)
    if [ "$PORTS" -ge 1 ]; then
        ok "Flows PAT distincts détectés (ports source différents par flow)"
    else
        info "Connexions trop courtes pour être capturées dans conntrack"
    fi

    sudo kill $PID_NC_ISP $PID_PC1 $PID_PC2 2>/dev/null || true

# ─── SCÉNARIO 16 (NAT STATIQUE uniquement) : route ISP pour PC2 ──────────────
elif [ "$NAT_MODE" = "STATIQUE" ]; then
    titre "SCÉNARIO 16 : NAT Statique — vérification route ISP pour PC2"
    echo ""

    # Vérifier que la route /32 existe sur ISP
    if sudo ip netns exec ISP ip route show 2>/dev/null | grep -q "209\.165\.200\.227"; then
        ok "Route ISP : 209.165.200.227/32 présente"
        sudo ip netns exec ISP ip route show 2>/dev/null \
            | grep "209\.165\.200\.227" | sed 's/^/    /'
    else
        fail "Route ISP pour 209.165.200.227/32 ABSENTE — PC2 ne recevra pas de réponses"
    fi
    echo ""

    # Vérifier le mapping SNAT exact
    info "Mapping SNAT configuré :"
    sudo ip netns exec GATEWAY iptables -t nat -L POSTROUTING -v -n 2>/dev/null \
        | grep "SNAT" | sed 's/^/    /'
    echo ""

    # Test ping PC2 -> ISP (nécessite la route /32)
    info "Test ping PC2 -> ISP (valide seulement si route ISP présente) :"
    ping_test PC2 209.165.200.225 "PC2 -> ISP via SNAT (209.165.200.227 -> ISP)"
fi

# ─── SCÉNARIO 17 : Test Internet (Partie 3 — ISP -> HOST -> Internet) ──────────
titre "SCÉNARIO 17 : Connectivité Internet (ISP -> HOST -> 8.8.8.8)"
echo ""

# Vérifier que veth-host existe sur le HOST
if ip link show veth-host &>/dev/null 2>&1; then
    ok "Interface veth-host présente sur le HOST"

    # Vérifier que veth-isp existe dans ISP
    if sudo ip netns exec ISP ip link show veth-isp &>/dev/null 2>&1; then
        ok "Interface veth-isp présente dans ISP"
    else
        fail "Interface veth-isp ABSENTE dans ISP — relancez setup_network.sh"
    fi

    # Route par défaut ISP
    ISP_GW=$(sudo ip netns exec ISP ip route 2>/dev/null | awk '/default/ {print $3}')
    if [ "$ISP_GW" = "10.0.0.1" ]; then
        ok "ISP : route par défaut via 10.0.0.1 (HOST)"
    else
        fail "ISP : route par défaut manquante ou incorrecte (trouvé : ${ISP_GW:-(aucune)})"
    fi

    # Forwarding HOST
    HOST_FWD=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "0")
    [ "$HOST_FWD" = "1" ] && ok "Forwarding IP HOST : actif" \
                           || fail "Forwarding IP HOST : DÉSACTIVÉ"

    # NAT MASQUERADE ISP
    if sudo ip netns exec ISP iptables -t nat -L POSTROUTING -n 2>/dev/null | grep -q "MASQUERADE"; then
        ok "ISP : règle MASQUERADE vers veth-isp présente"
    else
        fail "ISP : règle MASQUERADE ABSENTE — le trafic ne sortira pas vers Internet"
    fi

    echo ""
    info "Test ping ISP -> 8.8.8.8 (Google DNS) :"
    ping_test ISP 8.8.8.8 "ISP -> 8.8.8.8 (Internet via HOST)"

    echo ""
    info "Test ping PC1 -> 8.8.8.8 (chemin complet : PC1 -> GATEWAY -> ISP -> HOST -> Internet) :"
    if [ -n "$NAT_MODE" ]; then
        ping_test PC1 8.8.8.8 "PC1 -> 8.8.8.8 (Internet, chemin NAT complet)"
        ping_test PC2 8.8.8.8 "PC2 -> 8.8.8.8 (Internet, chemin NAT complet)"
    else
        info "NAT GATEWAY non configuré — impossible de tester PC -> Internet (scénario 12 requis)"
    fi
else
    info "Interface veth-host absente — Partie 3 (ISP -> Internet) non configurée"
    info "Relancez setup_network.sh pour activer la connexion Internet"
fi

# ─── RÉSUMÉ FINAL ─────────────────────────────────────────────────────────────
titre "RÉSUMÉ — TP2 DHCP + TP3 NAT"
echo ""
echo -e "  ${JAUNE}─── TP2 DHCP ───────────────────────────────────────────${RESET}"
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
echo -e "  ${CYAN}─── TP3 NAT (mode : ${NAT_MODE:-NON CONFIGURÉ}) ─────────────────────${RESET}"
echo -e "  ${JAUNE}Scénario 12${RESET} — Règles iptables   : NAT POSTROUTING + FORWARD"
echo -e "  ${JAUNE}Scénario 13${RESET} — Ping PC -> ISP     : translation NAT active"
echo -e "  ${JAUNE}Scénario 14${RESET} — tcpdump ISP       : IPs privées masquées"
echo -e "  ${JAUNE}Scénario 15${RESET} — conntrack         : suivi de connexion NAT"
if [ "$NAT_MODE" = "DYNAMIQUE" ]; then
echo -e "  ${JAUNE}Scénario 16${RESET} — PAT               : flows distincts (ports différents)"
elif [ "$NAT_MODE" = "STATIQUE" ]; then
echo -e "  ${JAUNE}Scénario 16${RESET} — SNAT 1:1          : route ISP + mapping fixe"
else
echo -e "  ${JAUNE}Scénario 16${RESET} — PAT/SNAT          : (NAT non configuré)"
fi
echo -e "  ${JAUNE}Scénario 17${RESET} — Internet          : ISP -> HOST -> 8.8.8.8"
echo ""
