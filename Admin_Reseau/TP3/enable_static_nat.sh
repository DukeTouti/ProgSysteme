#!/bin/bash
# =============================================================================
# TP3 - Configuration du NAT Statique (SNAT 1:1)
# Auteur : HATHOUTI Mohammed Taha
#
# Mapping statique :
#   PC1 (192.168.10.10) -> 209.165.200.226  (IP WAN du GATEWAY)
#   PC2 (192.168.20.10) -> 209.165.200.227  (IP publique dédiée)
# =============================================================================

set -e

VERT="\e[32m"; ROUGE="\e[31m"; JAUNE="\e[33m"; BLEU="\e[34m"; RESET="\e[0m"
ok()   { echo -e "${VERT}[OK]${RESET}    $1"; }
info() { echo -e "${BLEU}[INFO]${RESET}  $1"; }
warn() { echo -e "${JAUNE}[WARN]${RESET}  $1"; }
fail() { echo -e "${ROUGE}[ERREUR]${RESET} $1"; exit 1; }

# ─── VÉRIFICATION DES PRÉREQUIS ──────────────────────────────────────────────
info "Vérification des prérequis (réseau TP0)..."
for ns in PC1 PC2 GATEWAY ISP; do
    if ! sudo ip netns list | grep -q "^${ns}"; then
        fail "Namespace $ns manquant — lancez d'abord : bash setup_network.sh"
    fi
done

# Vérifier que PC1 a bien son adresse statique LAN1
IP_PC1=$(sudo ip netns exec PC1 ip addr show veth-PC1-pc 2>/dev/null | grep -oP 'inet \K[\d.]+')
IP_PC2=$(sudo ip netns exec PC2 ip addr show veth-PC2-pc 2>/dev/null | grep -oP 'inet \K[\d.]+')

[ "$IP_PC1" = "192.168.10.10" ] && ok "PC1 adresse statique : 192.168.10.10" \
    || warn "PC1 adresse inattendue sur veth-PC1-pc : ${IP_PC1:-(aucune)}"
[ "$IP_PC2" = "192.168.20.10" ] && ok "PC2 adresse statique : 192.168.20.10" \
    || warn "PC2 adresse inattendue sur veth-PC2-pc : ${IP_PC2:-(aucune)}"
echo ""

# ─── ÉTAPE 1 : ACTIVATION DU FORWARDING IP ───────────────────────────────────
info "=== ÉTAPE 1 : Activation du forwarding IP sur GATEWAY ==="
sudo ip netns exec GATEWAY sysctl -w net.ipv4.ip_forward=1 2>/dev/null
ok "Forwarding IP GATEWAY : actif"
echo ""

# ─── ÉTAPE 2 : NETTOYAGE DES RÈGLES IPTABLES ─────────────────────────────────
info "=== ÉTAPE 2 : Nettoyage des règles iptables (état propre) ==="
sudo ip netns exec GATEWAY iptables -F              && ok "Règles filter vidées"
sudo ip netns exec GATEWAY iptables -t nat -F       && ok "Règles NAT vidées"
sudo ip netns exec GATEWAY iptables -X              && ok "Chaînes personnalisées supprimées"
sudo ip netns exec GATEWAY iptables -P FORWARD ACCEPT && ok "Politique FORWARD -> ACCEPT"
echo ""

# ─── ÉTAPE 3 : CONFIGURATION DU NAT STATIQUE (SNAT 1:1) ─────────────────────
info "=== ÉTAPE 3 : Règles SNAT (mapping 1:1 IP privée 6> IP publique) ==="
#
#   PC1 (192.168.10.10) -> NAT -> 209.165.200.226 (IP WAN déjà sur veth3)
#   PC2 (192.168.20.10) -> NAT -> 209.165.200.227 (IP publique dédiée)
#

sudo ip netns exec GATEWAY iptables -t nat -A POSTROUTING \
    -s 192.168.10.10 -o veth3 -j SNAT --to-source 209.165.200.226
ok "SNAT : 192.168.10.10 (PC1) -> 209.165.200.226"

sudo ip netns exec GATEWAY iptables -t nat -A POSTROUTING \
    -s 192.168.20.10 -o veth3 -j SNAT --to-source 209.165.200.227
ok "SNAT : 192.168.20.10 (PC2) -> 209.165.200.227"
echo ""

# ─── ÉTAPE 4 : RÈGLES FORWARD ────────────────────────────────────────────────
info "=== ÉTAPE 4 : Règles FORWARD LAN -> WAN et retour ==="

# LAN → WAN
sudo ip netns exec GATEWAY iptables -A FORWARD -i gw1 -o veth3 -j ACCEPT
ok "FORWARD : gw1 (LAN1) -> veth3 (WAN)"

sudo ip netns exec GATEWAY iptables -A FORWARD -i gw2 -o veth3 -j ACCEPT
ok "FORWARD : gw2 (LAN2) -> veth3 (WAN)"

# WAN → LAN (réponses uniquement)
sudo ip netns exec GATEWAY iptables -A FORWARD -i veth3 -o gw1 \
    -m state --state ESTABLISHED,RELATED -j ACCEPT
ok "FORWARD retour : veth3 -> gw1 (connexions établies)"

sudo ip netns exec GATEWAY iptables -A FORWARD -i veth3 -o gw2 \
    -m state --state ESTABLISHED,RELATED -j ACCEPT
ok "FORWARD retour : veth3 -> gw2 (connexions établies)"
echo ""

# ─── ÉTAPE 5 : ROUTE PAR DÉFAUT DU GATEWAY VERS ISP ─────────────────────────
info "=== ÉTAPE 5 : Route par défaut GATEWAY -> ISP ==="
# Nécessaire pour que les paquets NATés puissent sortir
sudo ip netns exec GATEWAY ip route replace default via 209.165.200.225 dev veth3 2>/dev/null \
    && ok "GATEWAY : route par défaut via 209.165.200.225 (ISP)" \
    || warn "Route par défaut déjà présente ou impossible à ajouter"
echo ""

# ─── ÉTAPE 6 : ROUTE STATIQUE ISP -> IP PUBLIQUE PC2 ─────────────────────────
info "=== ÉTAPE 6 : Route hôte sur ISP pour l'IP publique de PC2 ==="
#
# PROBLÈME : 209.165.200.227 n'existe sur aucune interface ISP.
# L'ISP ne sait pas où envoyer les réponses -> paquets perdus.
# SOLUTION : ajouter une route /32 sur ISP pointant vers l'IP WAN du GATEWAY.
#
sudo ip netns exec ISP ip route replace 209.165.200.227/32 \
    via 209.165.200.226 dev isp1 2>/dev/null \
    && ok "ISP : route 209.165.200.227/32 via 209.165.200.226 (GATEWAY WAN)" \
    || warn "Route ISP pour 209.165.200.227 déjà présente"
echo ""

# ─── ÉTAPE 7 : VÉRIFICATION ───────────────────────────────────────────────────
info "=== ÉTAPE 7 : Vérification de la configuration SNAT ==="
echo ""
echo -e "  ${JAUNE}Règles iptables NAT (POSTROUTING) :${RESET}"
sudo ip netns exec GATEWAY iptables -t nat -L POSTROUTING -v -n | sed 's/^/    /'
echo ""
echo -e "  ${JAUNE}Table de routage ISP :${RESET}"
sudo ip netns exec ISP ip route 2>/dev/null | sed 's/^/    /'
echo ""

# ─── ÉTAPE 8 : TESTS DE CONNECTIVITÉ ─────────────────────────────────────────
info "=== ÉTAPE 8 : Tests de connectivité PC -> ISP ==="
echo ""

ping_test() {
    local ns="$1" dest="$2" label="$3"
    if sudo ip netns exec "$ns" ping -4 -c 3 -W 2 "$dest" &>/dev/null; then
        ok "$label"
    else
        warn "$label — ÉCHEC"
    fi
}

ping_test PC1 209.165.200.225 "PC1 -> ISP (via 209.165.200.226)"
ping_test PC2 209.165.200.225 "PC2 -> ISP (via 209.165.200.227 -> route ISP corrigée)"
echo ""

echo -e "  ${BLEU}[INFO]${RESET}  Pour observer la translation par tcpdump :"
echo "    sudo ip netns exec ISP tcpdump -n -i isp1 icmp"
echo "    sudo ip netns exec GATEWAY conntrack -L"
echo ""

# ─── RÉSUMÉ ───────────────────────────────────────────────────────────────────
echo -e "${VERT}============================================================${RESET}"
echo -e "${VERT}        NAT Statique (SNAT 1:1) configuré !${RESET}"
echo -e "${VERT}============================================================${RESET}"
echo ""
echo "  Mapping NAT statique :"
echo "    PC1 : 192.168.10.10 -> 209.165.200.226 (IP WAN GATEWAY)"
echo "    PC2 : 192.168.20.10 -> 209.165.200.227 (IP publique dédiée)"
echo ""
echo "  Route ISP ajoutée :"
echo "    209.165.200.227/32 via 209.165.200.226 dev isp1"
echo ""
echo "  Pour nettoyer : bash clean_static_nat.sh"
echo ""
