#!/bin/bash
# =============================================================================
# TP0 - Construire un réseau virtuel
# Script de déploiement du réseau virtuel avec namespaces
# Auteur : HATHOUTI Mohammed Taha
# =============================================================================

set -e

VERT="\e[32m"; ROUGE="\e[31m"; JAUNE="\e[33m"; BLEU="\e[34m"; RESET="\e[0m"
ok()   { echo -e "${VERT}[OK]${RESET} $1"; }
info() { echo -e "${BLEU}[INFO]${RESET} $1"; }
warn() { echo -e "${JAUNE}[ATTENTION]${RESET} $1"; }

# ─── ÉTAPE 0 : NETTOYAGE PRÉVENTIF ───────────────────────────────────────────
info "Nettoyage préventif..."
for ns in PC1 PC2 PC3 PC4 PC5 PC6 SW1 SW2 GATEWAY ISP; do
	sudo ip netns list | grep -q "^${ns}" && sudo ip netns del "$ns" 2>/dev/null && warn "Namespace $ns supprimé"
done

for lien in veth-PC1-pc veth-PC1-sw veth-PC2-pc veth-PC2-sw \
            veth-PC3-pc veth-PC3-sw veth-PC4-pc veth-PC4-sw \
            veth-PC5-pc veth-PC5-sw veth-PC6-pc veth-PC6-sw \
            gw-lan1 gw-lan1-sw gw-lan2 gw-lan2-sw veth3 isp1; do
	sudo ip link show "$lien" &>/dev/null && sudo ip link del "$lien" 2>/dev/null && warn "Lien $lien supprimé"
done

ok "Nettoyage terminé"; echo ""

# ─── ÉTAPE 1 : CRÉATION DES NAMESPACES ───────────────────────────────────────
info "=== ÉTAPE 1 : Création des namespaces ==="
for ns in PC1 PC2 PC3 PC4 PC5 PC6 SW1 SW2 GATEWAY ISP; do
    sudo ip netns add "$ns" && ok "Namespace $ns créé"
done
echo ""

# ─── ÉTAPE 2 : CRÉATION DES BRIDGES DANS SW1 ET SW2 ─────────────────────────
info "=== ÉTAPE 2 : Création des bridges Linux (br-lan1, br-lan2) ==="
 
# Bridge LAN1 dans SW1
sudo ip netns exec SW1 ip link add br-lan1 type bridge
sudo ip netns exec SW1 ip link set br-lan1 up
ok "br-lan1 créé dans SW1"
 
# Bridge LAN2 dans SW2
sudo ip netns exec SW2 ip link add br-lan2 type bridge
sudo ip netns exec SW2 ip link set br-lan2 up
ok "br-lan2 créé dans SW2"
echo ""

# ─── ÉTAPE 3 : CRÉATION DES PAIRES VETH ─────────────────────────────────────
info "=== ÉTAPE 3 : Création des liens virtuels (veth pairs) ==="
 
# LAN1 : PC1, PC3, PC5 <--> SW1
sudo ip link add veth-PC1-pc type veth peer name veth-PC1-sw && ok "veth-PC1-pc <-> veth-PC1-sw"
sudo ip link add veth-PC3-pc type veth peer name veth-PC3-sw && ok "veth-PC3-pc <-> veth-PC3-sw"
sudo ip link add veth-PC5-pc type veth peer name veth-PC5-sw && ok "veth-PC5-pc <-> veth-PC5-sw"
 
# LAN2 : PC2, PC4, PC6 <--> SW2
sudo ip link add veth-PC2-pc type veth peer name veth-PC2-sw && ok "veth-PC2-pc <-> veth-PC2-sw"
sudo ip link add veth-PC4-pc type veth peer name veth-PC4-sw && ok "veth-PC4-pc <-> veth-PC4-sw"
sudo ip link add veth-PC6-pc type veth peer name veth-PC6-sw && ok "veth-PC6-pc <-> veth-PC6-sw"
 
# GATEWAY <--> SW1 (LAN1)
sudo ip link add gw-lan1 type veth peer name gw-lan1-sw && ok "gw-lan1 <-> gw-lan1-sw (GATEWAY ↔ SW1)"
 
# GATEWAY <--> SW2 (LAN2)
sudo ip link add gw-lan2 type veth peer name gw-lan2-sw && ok "gw-lan2 <-> gw-lan2-sw (GATEWAY ↔ SW2)"
 
# GATEWAY <--> ISP (WAN)
sudo ip link add veth3 type veth peer name isp1 && ok "veth3 <-> isp1 (GATEWAY ↔ ISP WAN)"
echo ""

# ─── ÉTAPE 4 : ASSIGNATION AUX NAMESPACES ────────────────────────────────────
info "=== ÉTAPE 4 : Assignation des interfaces aux namespaces ==="
 
# PC1 -> PC6
sudo ip link set veth-PC1-pc netns PC1     && ok "veth-PC1-pc -> PC1"
sudo ip link set veth-PC2-pc netns PC2     && ok "veth-PC2-pc -> PC2"
sudo ip link set veth-PC3-pc netns PC3     && ok "veth-PC3-pc -> PC3"
sudo ip link set veth-PC4-pc netns PC4     && ok "veth-PC4-pc -> PC4"
sudo ip link set veth-PC5-pc netns PC5     && ok "veth-PC5-pc -> PC5"
sudo ip link set veth-PC6-pc netns PC6     && ok "veth-PC6-pc -> PC6"
 
# Côtés switches (SW1)
sudo ip link set veth-PC1-sw netns SW1     && ok "veth-PC1-sw -> SW1"
sudo ip link set veth-PC3-sw netns SW1     && ok "veth-PC3-sw -> SW1"
sudo ip link set veth-PC5-sw netns SW1     && ok "veth-PC5-sw -> SW1"
sudo ip link set gw-lan1-sw  netns SW1     && ok "gw-lan1-sw -> SW1"
 
# Côtés switches (SW2)
sudo ip link set veth-PC2-sw netns SW2     && ok "veth-PC2-sw -> SW2"
sudo ip link set veth-PC4-sw netns SW2     && ok "veth-PC4-sw -> SW2"
sudo ip link set veth-PC6-sw netns SW2     && ok "veth-PC6-sw -> SW2"
sudo ip link set gw-lan2-sw  netns SW2     && ok "gw-lan2-sw -> SW2"
 
# GATEWAY
sudo ip link set gw-lan1  netns GATEWAY    && ok "gw-lan1 -> GATEWAY"
sudo ip link set gw-lan2  netns GATEWAY    && ok "gw-lan2 -> GATEWAY"
sudo ip link set veth3    netns GATEWAY    && ok "veth3 -> GATEWAY"
 
# ISP
sudo ip link set isp1 netns ISP            && ok "isp1 -> ISP"
echo ""

# ─── ÉTAPE 5 : ATTACHER LES VETH AU BRIDGE ───────────────────────────────────
info "=== ÉTAPE 5 : Attachement des interfaces aux bridges ==="
 
# SW1 (br-lan1) <- PC1, PC3, PC5 + côté GATEWAY
for iface in veth-PC1-sw veth-PC3-sw veth-PC5-sw gw-lan1-sw; do
    sudo ip netns exec SW1 ip link set "$iface" up
    sudo ip netns exec SW1 ip link set "$iface" master br-lan1
    ok "$iface rattaché à br-lan1 (SW1)"
done
 
# SW2 (br-lan2) <- PC2, PC4, PC6 + côté GATEWAY
for iface in veth-PC2-sw veth-PC4-sw veth-PC6-sw gw-lan2-sw; do
    sudo ip netns exec SW2 ip link set "$iface" up
    sudo ip netns exec SW2 ip link set "$iface" master br-lan2
    ok "$iface rattaché à br-lan2 (SW2)"
done
echo ""

# ─── ÉTAPE 6 : ADRESSAGE IP ET ACTIVATION ────────────────────────────────────
info "=== ÉTAPE 6 : Adressage IP et activation des interfaces ==="
 
# LAN1 : PC1, PC3, PC5
sudo ip netns exec PC1 ip addr add 192.168.10.10/24 dev veth-PC1-pc
sudo ip netns exec PC1 ip link set veth-PC1-pc up
sudo ip netns exec PC1 ip link set lo up
ok "PC1 : veth-PC1-pc = 192.168.10.10/24 [UP]"
 
sudo ip netns exec PC3 ip addr add 192.168.10.11/24 dev veth-PC3-pc
sudo ip netns exec PC3 ip link set veth-PC3-pc up
sudo ip netns exec PC3 ip link set lo up
ok "PC3 : veth-PC3-pc = 192.168.10.11/24 [UP]"
 
sudo ip netns exec PC5 ip addr add 192.168.10.12/24 dev veth-PC5-pc
sudo ip netns exec PC5 ip link set veth-PC5-pc up
sudo ip netns exec PC5 ip link set lo up
ok "PC5 : veth-PC5-pc = 192.168.10.12/24 [UP]"
 
# LAN2 : PC2, PC4, PC6
sudo ip netns exec PC2 ip addr add 192.168.20.10/24 dev veth-PC2-pc
sudo ip netns exec PC2 ip link set veth-PC2-pc up
sudo ip netns exec PC2 ip link set lo up
ok "PC2 : veth-PC2-pc = 192.168.20.10/24 [UP]"
 
sudo ip netns exec PC4 ip addr add 192.168.20.11/24 dev veth-PC4-pc
sudo ip netns exec PC4 ip link set veth-PC4-pc up
sudo ip netns exec PC4 ip link set lo up
ok "PC4 : veth-PC4-pc = 192.168.20.11/24 [UP]"
 
sudo ip netns exec PC6 ip addr add 192.168.20.12/24 dev veth-PC6-pc
sudo ip netns exec PC6 ip link set veth-PC6-pc up
sudo ip netns exec PC6 ip link set lo up
ok "PC6 : veth-PC6-pc = 192.168.20.12/24 [UP]"
 
# GATEWAY
sudo ip netns exec GATEWAY ip addr add 192.168.10.1/24 dev gw-lan1
sudo ip netns exec GATEWAY ip addr add 192.168.20.1/24 dev gw-lan2
sudo ip netns exec GATEWAY ip addr add 209.165.200.226/27 dev veth3
sudo ip netns exec GATEWAY ip link set gw-lan1 up
sudo ip netns exec GATEWAY ip link set gw-lan2 up
sudo ip netns exec GATEWAY ip link set veth3 up
sudo ip netns exec GATEWAY ip link set lo up
ok "GATEWAY : gw-lan1=192.168.10.1 | gw-lan2=192.168.20.1 | veth3=209.165.200.226 [UP]"
 
# ISP
sudo ip netns exec ISP ip addr add 209.165.200.225/27 dev isp1
sudo ip netns exec ISP ip link set isp1 up
sudo ip netns exec ISP ip link set lo up
ok "ISP : isp1 = 209.165.200.225/27 [UP]"
echo ""

# ─── ÉTAPE 7 : CONFIGURATION DU ROUTAGE ──────────────────────────────────────
info "=== ÉTAPE 7 : Configuration du routage ==="
 
# Routes par défaut des PCs vers leur passerelle respective
for ns in PC1 PC3 PC5; do
    sudo ip netns exec "$ns" ip route add default via 192.168.10.1
    ok "$ns : route par défaut via 192.168.10.1 (GATEWAY LAN1)"
done
 
for ns in PC2 PC4 PC6; do
    sudo ip netns exec "$ns" ip route add default via 192.168.20.1
    ok "$ns : route par défaut via 192.168.20.1 (GATEWAY LAN2)"
done
 
# Route par défaut de GATEWAY vers ISP
sudo ip netns exec GATEWAY ip route add default via 209.165.200.225
ok "GATEWAY : route par défaut via 209.165.200.225 (FAI)"
echo ""

# ─── ÉTAPE 8 : FORWARDING IP + DÉSACTIVATION POUR ARP ───────────────────────
info "=== ÉTAPE 8 : Forwarding IP sur GATEWAY ==="
 
# Forwarding activé (nécessaire pour routage inter-LAN plus tard)
sudo ip netns exec GATEWAY sysctl -w net.ipv4.ip_forward=1 2>/dev/null || true
sudo ip netns exec GATEWAY bash -c 'echo 1 > /proc/sys/net/ipv4/ip_forward' 2>/dev/null || true
 
FWD=$(sudo ip netns exec GATEWAY cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "?")
ok "Forwarding IP GATEWAY : $FWD (1 = actif)"

# ─── NOTE : Pour les observations ARP (Partie 3 du TP), désactiver avec : ────
echo ""
warn "Pour observer l'ARP pur (Partie 3), exécutez manuellement :"
echo -e "  ${JAUNE}sudo ip netns exec GATEWAY sysctl -w net.ipv4.ip_forward=0${RESET}"
echo ""

# ─── RÉSUMÉ ───────────────────────────────────────────────────────────────────
echo -e "${VERT}============================================================${RESET}"
echo -e "${VERT}        Réseau virtuel TP1 déployé avec succès !${RESET}"
echo -e "${VERT}============================================================${RESET}"
echo ""
echo "  LAN1 (SW1 / br-lan1) :"
echo "    PC1 : 192.168.10.10/24   (veth-PC1-pc)"
echo "    PC3 : 192.168.10.11/24   (veth-PC3-pc)"
echo "    PC5 : 192.168.10.12/24   (veth-PC5-pc)"
echo ""
echo "  LAN2 (SW2 / br-lan2) :"
echo "    PC2 : 192.168.20.10/24   (veth-PC2-pc)"
echo "    PC4 : 192.168.20.11/24   (veth-PC4-pc)"
echo "    PC6 : 192.168.20.12/24   (veth-PC6-pc)"
echo ""
echo "  GATEWAY :"
echo "    gw-lan1 : 192.168.10.1/24"
echo "    gw-lan2 : 192.168.20.1/24"
echo "    veth3   : 209.165.200.226/27 (WAN)"
echo ""
echo "  ISP :"
echo "    isp1 : 209.165.200.225/27"
echo ""
echo "  Lancez : bash test_connectivite.sh"
echo ""

# ─── ÉTAPE 9 : CONNEXION ISP -> INTERNET (TP3 PARTIE 3) ───────────────────────
info "=== ÉTAPE 9 : Connexion ISP ↔ HOST (accès Internet réel) ==="

# Nettoyage préventif des interfaces résiduelles
sudo ip link del veth-isp  2>/dev/null && warn "Interface veth-isp supprimée (résidu)" || true
sudo ip link del veth-host 2>/dev/null && warn "Interface veth-host supprimée (résidu)" || true
sudo ip netns exec ISP ip link del veth-isp 2>/dev/null || true

# Création de la paire veth entre ISP et HOST
sudo ip link add veth-isp type veth peer name veth-host
ok "Paire veth créée : veth-isp <-> veth-host"

# veth-isp dans le namespace ISP
sudo ip link set veth-isp netns ISP
ok "veth-isp assignée au namespace ISP"

# Adressage IP
sudo ip netns exec ISP ip addr add 10.0.0.2/30 dev veth-isp
sudo ip netns exec ISP ip link set veth-isp up
ok "ISP : veth-isp = 10.0.0.2/30 [UP]"

sudo ip addr add 10.0.0.1/30 dev veth-host 2>/dev/null || warn "10.0.0.1/30 déjà présente sur veth-host"
sudo ip link set veth-host up
ok "HOST : veth-host = 10.0.0.1/30 [UP]"

# Route par défaut dans ISP vers le HOST
sudo ip netns exec ISP ip route replace default via 10.0.0.1
ok "ISP : route par défaut via 10.0.0.1 (HOST)"

# Forwarding IP dans ISP
sudo ip netns exec ISP sysctl -w net.ipv4.ip_forward=1 2>/dev/null
ok "Forwarding IP ISP : actif"

# NAT dans ISP (masque les IPs de lab derrière veth-isp)
sudo ip netns exec ISP iptables -t nat -F
sudo ip netns exec ISP iptables -F
sudo ip netns exec ISP iptables -A FORWARD -i isp1    -o veth-isp -j ACCEPT
sudo ip netns exec ISP iptables -A FORWARD -i veth-isp -o isp1 \
    -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo ip netns exec ISP iptables -t nat -A POSTROUTING -o veth-isp -j MASQUERADE
ok "ISP : MASQUERADE sur veth-isp configuré"

# Forwarding IP sur le HOST + NAT vers Internet
sudo sysctl -w net.ipv4.ip_forward=1 2>/dev/null
ok "Forwarding IP HOST : actif"

HOST_IF=$(ip route 2>/dev/null | awk '/default/ {print $5; exit}')
if [ -n "$HOST_IF" ]; then
    sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/30 -o "$HOST_IF" -j MASQUERADE 2>/dev/null \
        && ok "HOST : MASQUERADE 10.0.0.0/30 -> $HOST_IF (Internet)" \
        || warn "Règle MASQUERADE déjà présente sur $HOST_IF"
else
    warn "Interface Internet du HOST non détectée — MASQUERADE non configuré"
fi
echo ""

echo -e "${VERT}============================================================${RESET}"
echo -e "${VERT}  Connexion ISP -> Internet configurée !${RESET}"
echo -e "${VERT}============================================================${RESET}"
echo ""
echo "  Chemin complet :"
echo "    PC1/PC2 -> GATEWAY (NAT) -> ISP (NAT) -> HOST -> Internet"
echo ""
echo "  Test Internet depuis les PCs (après enable_dynamic_nat.sh) :"
echo "    sudo ip netns exec PC1 ping 8.8.8.8"
echo ""
