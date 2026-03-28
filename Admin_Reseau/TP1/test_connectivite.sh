#!/bin/bash
# =============================================================================
# TP1 - Script de tests de connectivité + observations ARP
# =============================================================================

VERT="\e[32m"; ROUGE="\e[31m"; JAUNE="\e[33m"; BLEU="\e[34m"; RESET="\e[0m"
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
echo -e "${JAUNE}  TP1 — Tests de connectivité + ARP réseau virtuel étendu${RESET}"
echo -e "${JAUNE}  $(date '+%d/%m/%Y %H:%M:%S')${RESET}"

# ─── SCÉNARIO 1 : Namespaces ──────────────────────────────────────────────────
titre "SCÉNARIO 1 : Existence des namespaces"
echo ""
sudo ip netns list
echo ""
for ns in PC1 PC2 PC3 PC4 PC5 PC6 SW1 SW2 GATEWAY ISP; do
    if sudo ip netns list | grep -q "^${ns}"; then
        ok "Namespace $ns présent"
    else
        fail "Namespace $ns MANQUANT"
    fi
done

# ─── SCÉNARIO 2 : Interfaces UP ───────────────────────────────────────────────
titre "SCÉNARIO 2 : Interfaces actives (UP)"
echo ""
for ns in PC1 PC2 PC3 PC4 PC5 PC6; do
    IFACES=$(sudo ip netns exec "$ns" ip link show 2>/dev/null \
        | grep -v lo | grep "UP" | grep -oP '^\d+: \K[\w-]+(?=@|:)' | tr '\n' ' ')
    echo -e "  ${JAUNE}$ns${RESET} → ${IFACES:-aucune interface UP}"
done
for ns in SW1 SW2 GATEWAY ISP; do
    IFACES=$(sudo ip netns exec "$ns" ip link show 2>/dev/null \
        | grep -v lo | grep "UP" | grep -oP '^\d+: \K[\w-]+(?=@|:)' | tr '\n' ' ')
    echo -e "  ${JAUNE}$ns${RESET} → ${IFACES:-aucune interface UP}"
done

# ─── SCÉNARIO 3 : Configuration IP ───────────────────────────────────────────
titre "SCÉNARIO 3 : Configuration IP"
echo ""
printf "  %-10s %-20s %s\n" "Namespace" "Interface" "Adresse IP"
printf "  %-10s %-20s %s\n" "─────────" "───────────────────" "──────────────────"

declare -A NS_IFACE
NS_IFACE["PC1"]="veth-PC1-pc"
NS_IFACE["PC2"]="veth-PC2-pc"
NS_IFACE["PC3"]="veth-PC3-pc"
NS_IFACE["PC4"]="veth-PC4-pc"
NS_IFACE["PC5"]="veth-PC5-pc"
NS_IFACE["PC6"]="veth-PC6-pc"

for ns in PC1 PC2 PC3 PC4 PC5 PC6; do
    iface="${NS_IFACE[$ns]}"
    ip=$(sudo ip netns exec "$ns" ip addr show "$iface" 2>/dev/null | grep -oP 'inet \K[\d./]+')
    printf "  %-10s %-20s %s\n" "$ns" "$iface" "${ip:-(non configurée)}"
done

for iface in gw-lan1 gw-lan2 veth3; do
    ip=$(sudo ip netns exec GATEWAY ip addr show "$iface" 2>/dev/null | grep -oP 'inet \K[\d./]+')
    printf "  %-10s %-20s %s\n" "GATEWAY" "$iface" "${ip:-(non configurée)}"
done

ip=$(sudo ip netns exec ISP ip addr show isp1 2>/dev/null | grep -oP 'inet \K[\d./]+')
printf "  %-10s %-20s %s\n" "ISP" "isp1" "${ip:-(non configurée)}"

# ─── SCÉNARIO 4 : Connectivité locale LAN1 ───────────────────────────────────
titre "SCÉNARIO 4 : Connectivité locale LAN1 (via SW1/br-lan1)"
echo ""
ping_test PC1 192.168.10.11 "PC1 -> PC3  (192.168.10.11)"
ping_test PC1 192.168.10.12 "PC1 -> PC5  (192.168.10.12)"
ping_test PC3 192.168.10.10 "PC3 -> PC1  (192.168.10.10)"
ping_test PC5 192.168.10.10 "PC5 -> PC1  (192.168.10.10)"
ping_test PC1 192.168.10.1  "PC1 -> GATEWAY LAN1 (192.168.10.1)"

# ─── SCÉNARIO 5 : Connectivité locale LAN2 ───────────────────────────────────
titre "SCÉNARIO 5 : Connectivité locale LAN2 (via SW2/br-lan2)"
echo ""
ping_test PC2 192.168.20.11 "PC2 -> PC4  (192.168.20.11)"
ping_test PC2 192.168.20.12 "PC2 -> PC6  (192.168.20.12)"
ping_test PC4 192.168.20.10 "PC4 -> PC2  (192.168.20.10)"
ping_test PC6 192.168.20.10 "PC6 -> PC2  (192.168.20.10)"
ping_test PC2 192.168.20.1  "PC2 -> GATEWAY LAN2 (192.168.20.1)"

# ─── SCÉNARIO 6 : Forwarding IP désactivé → ARP/L2 pur ───────────────────────
titre "SCÉNARIO 6 : Isolation inter-LAN (forwarding désactivé)"
echo ""
info "Désactivation du forwarding IP sur GATEWAY..."
sudo ip netns exec GATEWAY sysctl -w net.ipv4.ip_forward=0 &>/dev/null || true

echo ""
info "Test PC1 -> PC2 (doit ÉCHOUER — LAN isolés) :"
if sudo ip netns exec PC1 ping -4 -c 2 -W 2 192.168.20.10 &>/dev/null; then
    echo -e "  ${ROUGE}[INATTENDU]${RESET} PC1 -> PC2 : ping passé alors qu'il ne devrait pas"
else
    echo -e "  ${VERT}[ATTENDU]${RESET}   PC1 -> PC2 : échec correct — forwarding désactivé"
fi

info "Réactivation du forwarding IP sur GATEWAY..."
sudo ip netns exec GATEWAY sysctl -w net.ipv4.ip_forward=1 &>/dev/null || true
sudo ip netns exec GATEWAY bash -c 'echo 1 > /proc/sys/net/ipv4/ip_forward' &>/dev/null || true

# ─── SCÉNARIO 7 : Routage inter-LAN ──────────────────────────────────────────
titre "SCÉNARIO 7 : Routage inter-LAN (forwarding réactivé)"
echo ""
ping_test PC1 192.168.20.10 "PC1 (LAN1) -> PC2 (LAN2) via GATEWAY"
ping_test PC1 192.168.20.11 "PC1 (LAN1) -> PC4 (LAN2) via GATEWAY"
ping_test PC2 192.168.10.10 "PC2 (LAN2) -> PC1 (LAN1) via GATEWAY"
ping_test PC5 192.168.20.12 "PC5 (LAN1) -> PC6 (LAN2) via GATEWAY"

# ─── SCÉNARIO 8 : Lien WAN ───────────────────────────────────────────────────
titre "SCÉNARIO 8 : Lien Passerelle ↔ FAI (WAN)"
echo ""
ping_test GATEWAY 209.165.200.225 "GATEWAY -> ISP (209.165.200.225)"
ping_test ISP     209.165.200.226 "ISP -> GATEWAY WAN (209.165.200.226)"

# ─── SCÉNARIO 9 : Bout-en-bout sans NAT ──────────────────────────────────────
titre "SCÉNARIO 9 : Test bout-en-bout PC -> FAI (sans NAT)"
echo ""
for ns in PC1 PC2; do
    info "Test $ns -> ISP (209.165.200.225) sans NAT..."
    if sudo ip netns exec "$ns" ping -c 2 -W 2 209.165.200.225 &>/dev/null; then
        echo -e "  ${ROUGE}[INATTENDU]${RESET} $ns -> ISP : le ping passe (NAT actif ?)"
    else
        echo -e "  ${VERT}[ATTENDU]${RESET}   $ns -> ISP : échec correct — ISP sans route retour vers réseau privé"
    fi
done
echo ""
echo -e "  ${JAUNE}Explication :${RESET} ISP ne connaît pas 192.168.x.0/24 -> Echo Reply abandonné."
echo -e "  => Le NAT (TP3) résoudra ce problème."

# ─── SCÉNARIO 10 : Tables ARP avant trafic ───────────────────────────────────
titre "SCÉNARIO 10 : Observation ARP — Tables avant/après ping"
echo ""

info "Vidage des tables ARP sur PC1, PC3, PC5..."
for ns in PC1 PC3 PC5; do
    sudo ip netns exec "$ns" ip neigh flush all 2>/dev/null || true
done

info "Tables ARP sur LAN1 AVANT ping :"
for ns in PC1 PC3 PC5; do
    ARP=$(sudo ip netns exec "$ns" ip neigh 2>/dev/null)
    echo -e "  ${JAUNE}$ns${RESET} : ${ARP:-(vide)}"
done

echo ""
info "Génération de trafic ARP : PC1 -> PC3 et PC1 -> PC5..."
sudo ip netns exec PC1 ping -c 2 -W 2 192.168.10.11 &>/dev/null || true
sudo ip netns exec PC1 ping -c 2 -W 2 192.168.10.12 &>/dev/null || true

echo ""
info "Tables ARP sur LAN1 APRÈS ping :"
for ns in PC1 PC3 PC5; do
    echo -e "  ${JAUNE}$ns${RESET} :"
    sudo ip netns exec "$ns" ip neigh 2>/dev/null | sed 's/^/    /' || echo "    (vide)"
done

# ─── SCÉNARIO 11 : Table MAC des switches ────────────────────────────────────
titre "SCÉNARIO 11 : Table de forwarding MAC (bridge fdb)"
echo ""
info "SW1 (br-lan1) — table MAC :"
sudo ip netns exec SW1 bridge fdb show | grep -v "permanent" | sed 's/^/  /' || echo "  (vide)"
echo ""
info "SW2 (br-lan2) — table MAC :"
sudo ip netns exec SW2 bridge fdb show | grep -v "permanent" | sed 's/^/  /' || echo "  (vide)"

# ─── SCÉNARIO 12 : ARP statique sur PC1 ──────────────────────────────────────
titre "SCÉNARIO 12 : ARP statique — PC1 -> PC3"
echo ""

# Récupérer l'adresse MAC de PC3
MAC_PC3=$(sudo ip netns exec PC3 ip link show veth-PC3-pc 2>/dev/null \
    | grep -oP 'link/ether \K[\da-f:]+')

info "Adresse MAC de PC3 (veth-PC3-pc) : $MAC_PC3"

# Supprimer toute entrée existante pour PC3 dans ARP de PC1
sudo ip netns exec PC1 ip neigh del 192.168.10.11 dev veth-PC1-pc 2>/dev/null || true

# Ajouter l'entrée ARP statique (permanente)
if [ -n "$MAC_PC3" ]; then
    sudo ip netns exec PC1 ip neigh add 192.168.10.11 \
        lladdr "$MAC_PC3" dev veth-PC1-pc nud permanent
    ok "Entrée ARP statique ajoutée sur PC1 : 192.168.10.11 -> $MAC_PC3 (PERMANENT)"
else
    fail "Impossible de récupérer la MAC de PC3"
fi

echo ""
info "Table ARP de PC1 après ajout statique :"
sudo ip netns exec PC1 ip neigh show | sed 's/^/  /'
echo ""
info "PC1 ne génèrera plus de requête ARP broadcast pour 192.168.10.11 (PC3)."

# ─── TABLES DE ROUTAGE ───────────────────────────────────────────────────────
titre "TABLES DE ROUTAGE"
for ns in PC1 PC2 PC3 PC4 PC5 PC6 GATEWAY ISP; do
    echo -e "\n  ${JAUNE}$ns :${RESET}"
    sudo ip netns exec "$ns" ip route 2>/dev/null | sed 's/^/    /' || echo "    (vide)"
done

# ─── RÉSUMÉ ──────────────────────────────────────────────────────────────────
titre "RÉSUMÉ FORWARDING IP"
echo ""
FWD=$(sudo ip netns exec GATEWAY cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "?")
echo -e "  Forwarding IP sur GATEWAY : ${VERT}$FWD${RESET} (1 = actif)"
echo ""
echo -e "  ${JAUNE}Rappel des fonctionnalités testées :${RESET}"
echo "   Connectivité L2 intra-LAN via bridges Linux (SW1/SW2)"
echo "   Isolation inter-LAN avec forwarding désactivé (observation ARP pur)"
echo "   Routage inter-LAN avec forwarding activé"
echo "   Lien WAN GATEWAY <-> ISP"
echo "   Échec attendu PC -> ISP sans NAT"
echo "   Observation ARP dynamique (avant/après ping)"
echo "   Table de forwarding MAC des bridges"
echo "   ARP statique permanent sur PC1 -> PC3"
echo ""
