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
for ns in PC1 PC2 GATEWAY ISP; do
	sudo ip netns list | grep -q "^${ns}" && sudo ip netns del "$ns" 2>/dev/null && warn "Namespace $ns supprimé"
done

for lien in veth1 veth2 veth3; do
	sudo ip link show "$lien" &>/dev/null && sudo ip link del "$lien" 2>/dev/null && warn "Lien $lien supprimé"
done

ok "Nettoyage terminé"; echo ""

# ─── ÉTAPE 1 : CRÉATION DES NAMESPACES ───────────────────────────────────────
info "=== ÉTAPE 1 : Création des namespaces ==="
sudo ip netns add PC1     && ok "Namespace PC1 créé"
sudo ip netns add PC2     && ok "Namespace PC2 créé"
sudo ip netns add GATEWAY && ok "Namespace GATEWAY créé"
sudo ip netns add ISP     && ok "Namespace ISP créé"
echo ""

# ─── ÉTAPE 2 : CRÉATION DES PAIRES VETH ─────────────────────────────────────
info "=== ÉTAPE 2 : Création des liens virtuels (veth pairs) ==="
sudo ip link add veth1 type veth peer name gw1  && ok "veth1 ↔ gw1  (PC1 ↔ GATEWAY LAN1)"
sudo ip link add veth2 type veth peer name gw2  && ok "veth2 ↔ gw2  (PC2 ↔ GATEWAY LAN2)"
sudo ip link add veth3 type veth peer name isp1 && ok "veth3 ↔ isp1 (GATEWAY ↔ ISP WAN)"
echo ""

# ─── ÉTAPE 3 : ASSIGNATION AUX NAMESPACES ────────────────────────────────────
info "=== ÉTAPE 3 : Assignation des interfaces aux namespaces ==="
sudo ip link set veth1 netns PC1     && ok "veth1  → PC1"
sudo ip link set veth2 netns PC2     && ok "veth2  → PC2"
sudo ip link set gw1   netns GATEWAY && ok "gw1    → GATEWAY"
sudo ip link set gw2   netns GATEWAY && ok "gw2    → GATEWAY"
sudo ip link set veth3 netns GATEWAY && ok "veth3  → GATEWAY"
sudo ip link set isp1  netns ISP     && ok "isp1   → ISP"
echo ""

# ─── ÉTAPE 4 : ADRESSAGE IP ET ACTIVATION ────────────────────────────────────
info "=== ÉTAPE 4 : Adressage IP et activation des interfaces ==="

sudo ip netns exec PC1 ip addr add 192.168.10.10/24 dev veth1
sudo ip netns exec PC1 ip link set veth1 up
sudo ip netns exec PC1 ip link set lo up
ok "PC1     : veth1 = 192.168.10.10/24 ${VERT}[UP]${RESET}"

sudo ip netns exec PC2 ip addr add 192.168.20.10/24 dev veth2
sudo ip netns exec PC2 ip link set veth2 up
sudo ip netns exec PC2 ip link set lo up
ok "PC2     : veth2 = 192.168.20.10/24 ${VERT}[UP]${RESET}"

sudo ip netns exec GATEWAY ip addr add 192.168.10.1/24 dev gw1
sudo ip netns exec GATEWAY ip addr add 192.168.20.1/24 dev gw2
sudo ip netns exec GATEWAY ip addr add 209.165.200.226/27 dev veth3
sudo ip netns exec GATEWAY ip link set gw1 up
sudo ip netns exec GATEWAY ip link set gw2 up
sudo ip netns exec GATEWAY ip link set veth3 up
sudo ip netns exec GATEWAY ip link set lo up
ok "GATEWAY : gw1=192.168.10.1/24 | gw2=192.168.20.1/24 | veth3=209.165.200.226/27 ${VERT}[UP]${RESET}"

sudo ip netns exec ISP ip addr add 209.165.200.225/27 dev isp1
sudo ip netns exec ISP ip link set isp1 up
sudo ip netns exec ISP ip link set lo up
ok "ISP     : isp1 = 209.165.200.225/27 ${VERT}[UP]${RESET}"
echo ""

# ─── ÉTAPE 5 : CONFIGURATION DU ROUTAGE ──────────────────────────────────────
info "=== ÉTAPE 5 : Configuration du routage ==="

sudo ip netns exec PC1 ip route add default via 192.168.10.1
ok "PC1     : route par défaut via 192.168.10.1"

sudo ip netns exec PC2 ip route add default via 192.168.20.1
ok "PC2     : route par défaut via 192.168.20.1"

sudo ip netns exec GATEWAY ip route add default via 209.165.200.225
ok "GATEWAY : route par défaut via 209.165.200.225 (FAI)"

echo ""

# ─── ÉTAPE 6 : FORWARDING IP ─────────────────────────────────────────────────
info "=== ÉTAPE 6 : Activation du forwarding IP ==="

# Méthode 1 : sysctl dans le namespace
sudo ip netns exec GATEWAY sysctl -w net.ipv4.ip_forward=1 2>/dev/null || true
# Méthode 2 : écriture directe dans /proc (fallback conteneur)
sudo ip netns exec GATEWAY bash -c 'echo 1 > /proc/sys/net/ipv4/ip_forward' 2>/dev/null || true
# Méthode 3 : activation globale hôte
sudo echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true

FWD=$(sudo ip netns exec GATEWAY cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "?")
ok "Forwarding IP GATEWAY : $FWD"; ok "(1=actif)"
echo ""

# ─── RÉSUMÉ ───────────────────────────────────────────────────────────────────
echo -e "${VERT}============================================================${RESET}"
echo -e "${VERT}            Réseau virtuel déployé avec succès !${RESET}"
echo -e "${VERT}============================================================${RESET}"
echo ""
echo "  PC1     : 192.168.10.10/24   (veth1)"
echo "  PC2     : 192.168.20.10/24   (veth2)"
echo "  GATEWAY : 192.168.10.1/24    (gw1 - LAN1)"
echo "            192.168.20.1/24    (gw2 - LAN2)"
echo "            209.165.200.226/27 (veth3 - WAN)"
echo "  ISP     : 209.165.200.225/27 (isp1)"
echo ""
echo "  Lancez : bash test_connectivite.sh"
echo ""
