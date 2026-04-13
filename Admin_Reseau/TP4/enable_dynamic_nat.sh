#!/bin/bash
# =============================================================================
# TP3 - Configuration du NAT Dynamique (MASQUERADE / PAT)
# Auteur : HATHOUTI Mohammed Taha
# Prérequis : setup_network.sh (TP0) + setup_dhcp.sh (TP2) exécutés
# =============================================================================

set -e

VERT="\e[32m"; ROUGE="\e[31m"; JAUNE="\e[33m"; BLEU="\e[34m"; RESET="\e[0m"
ok()   { echo -e "${VERT}[OK]${RESET}    $1"; }
info() { echo -e "${BLEU}[INFO]${RESET}  $1"; }
warn() { echo -e "${JAUNE}[WARN]${RESET}  $1"; }
fail() { echo -e "${ROUGE}[ERREUR]${RESET} $1"; exit 1; }

# ─── VÉRIFICATION DES PRÉREQUIS ──────────────────────────────────────────────
info "Vérification des prérequis (réseau TP0 + DHCP TP2)..."
for ns in PC1 PC2 GATEWAY ISP; do
	if ! sudo ip netns list | grep -q "^${ns}"; then
		fail "Namespace $ns manquant — lancez d'abord : bash setup_network.sh && bash setup_dhcp.sh"
	fi
done

# Vérifier que PC1 et PC2 ont bien une IP DHCP sur dhcp_pc1 / dhcp_pc2 (non bloquant)
set +e
for ns_num in 1 2; do
	IP=$(sudo ip netns exec "PC${ns_num}" ip addr show "dhcp_pc${ns_num}" 2>/dev/null | grep -oP 'inet \K[\d./]+')
	if [ -z "$IP" ]; then
		warn "PC${ns_num} : pas d'adresse DHCP sur dhcp_pc${ns_num} (normal si setup_dhcp.sh non lancé)"
	else
		ok "PC${ns_num} : adresse DHCP détectée ($IP)"
	fi
done
set -e

FWD=$(sudo ip netns exec GATEWAY cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "0")
[ "$FWD" != "1" ] && warn "IP forwarding désactivé sur GATEWAY — activation en cours..."
echo ""

# ─── ÉTAPE 1 : ACTIVATION DU FORWARDING IP ───────────────────────────────────
info "=== ÉTAPE 1 : Activation du forwarding IP sur GATEWAY ==="
sudo ip netns exec GATEWAY sysctl -w net.ipv4.ip_forward=1 2>/dev/null
FWD=$(sudo ip netns exec GATEWAY cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)
ok "Forwarding IP GATEWAY : $FWD (1 = actif)"
echo ""

# ─── ÉTAPE 2 : NETTOYAGE DES RÈGLES IPTABLES ─────────────────────────────────
info "=== ÉTAPE 2 : Nettoyage des règles iptables (état propre) ==="
sudo ip netns exec GATEWAY iptables -F                && ok "Règles filter vidées (-F)"
sudo ip netns exec GATEWAY iptables -t nat -F         && ok "Règles NAT vidées (-t nat -F)"
sudo ip netns exec GATEWAY iptables -X                && ok "Chaînes personnalisées supprimées (-X)"
sudo ip netns exec GATEWAY iptables -P FORWARD ACCEPT && ok "Politique FORWARD -> ACCEPT"
echo ""

# ─── ÉTAPE 3 : AUTORISER LE FORWARDING LAN -> WAN ────────────────────────────
info "=== ÉTAPE 3 : Règles FORWARD LAN -> WAN (gw1/gw2 -> veth3) ==="
sudo ip netns exec GATEWAY iptables -A FORWARD -i gw1 -o veth3 -j ACCEPT
ok "FORWARD : gw1 -> veth3 (PC1/LAN1 vers ISP)"

sudo ip netns exec GATEWAY iptables -A FORWARD -i gw2 -o veth3 -j ACCEPT
ok "FORWARD : gw2 -> veth3 (PC2/LAN2 vers ISP)"
echo ""

# ─── ÉTAPE 4 : AUTORISER LE TRAFIC RETOUR WAN → LAN ─────────────────────────
info "=== ÉTAPE 4 : Règles FORWARD retour WAN -> LAN (connexions établies) ==="
sudo ip netns exec GATEWAY iptables -A FORWARD -i veth3 -o gw1 \
	-m state --state ESTABLISHED,RELATED -j ACCEPT
ok "FORWARD retour : veth3 -> gw1 (réponses vers LAN1)"

sudo ip netns exec GATEWAY iptables -A FORWARD -i veth3 -o gw2 \
	-m state --state ESTABLISHED,RELATED -j ACCEPT
ok "FORWARD retour : veth3 -> gw2 (réponses vers LAN2)"
echo ""

# ─── ÉTAPE 5 : NAT DYNAMIQUE (MASQUERADE) ────────────────────────────────────
info "=== ÉTAPE 5 : NAT Dynamique MASQUERADE (PAT) ==="
sudo ip netns exec GATEWAY iptables -t nat -A POSTROUTING \
	-s 192.168.10.0/24 -o veth3 -j MASQUERADE
ok "MASQUERADE : LAN1 (192.168.10.0/24) -> veth3"

sudo ip netns exec GATEWAY iptables -t nat -A POSTROUTING \
	-s 192.168.20.0/24 -o veth3 -j MASQUERADE
ok "MASQUERADE : LAN2 (192.168.20.0/24) -> veth3"
echo ""

# ─── ÉTAPE 6 : VÉRIFICATION ───────────────────────────────────────────────────
info "=== ÉTAPE 6 : Vérification de la configuration NAT ==="
echo ""
echo -e "  ${JAUNE}Règles iptables NAT (POSTROUTING) :${RESET}"
sudo ip netns exec GATEWAY iptables -t nat -L POSTROUTING -v -n | sed 's/^/    /'
echo ""
echo -e "  ${JAUNE}Règles iptables FORWARD :${RESET}"
sudo ip netns exec GATEWAY iptables -L FORWARD -v -n | sed 's/^/    /'
echo ""

# ─── ÉTAPE 7 : TESTS DE CONNECTIVITÉ ─────────────────────────────────────────
info "=== ÉTAPE 7 : Tests de connectivité PC -> ISP ==="
echo ""

ping_test() {
	local ns="$1" dest="$2" label="$3"
	if sudo ip netns exec "$ns" ping -4 -c 3 -W 2 "$dest" &>/dev/null; then
		ok "$label"
	else
		warn "$label — ÉCHEC (vérifiez les routes et le DHCP)"
	fi
}

ping_test PC1 209.165.200.225 "PC1 -> ISP (209.165.200.225) via NAT dynamique"
ping_test PC2 209.165.200.225 "PC2 -> ISP (209.165.200.225) via NAT dynamique"
echo ""

# ─── RÉSUMÉ ───────────────────────────────────────────────────────────────────
echo -e "${VERT}============================================================${RESET}"
echo -e "${VERT}        NAT Dynamique (MASQUERADE) configuré !${RESET}"
echo -e "${VERT}============================================================${RESET}"
echo ""
echo "  Translation PAT :"
echo "    192.168.10.x:PORTX -> 209.165.200.226:PORT' -> ISP"
echo "    192.168.20.x:PORTX -> 209.165.200.226:PORT' -> ISP"
echo ""
echo "  Pour tester une connexion TCP longue durée :"
echo "    sudo ip netns exec ISP nc -l 80"
echo "    sudo ip netns exec PC1 nc 209.165.200.225 80"
echo "    sudo ip netns exec GATEWAY conntrack -L"
echo ""
echo "  Pour nettoyer : bash cleanup_dynamic_nat.sh"
echo ""
