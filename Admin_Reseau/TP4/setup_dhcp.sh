#!/bin/bash
# =============================================================================
# TP2 - Installation et Configuration d'un serveur DHCP
# Auteur : HATHOUTI Mohammed Taha
# =============================================================================

set -e

VERT="\e[32m"; ROUGE="\e[31m"; JAUNE="\e[33m"; BLEU="\e[34m"; RESET="\e[0m"
ok()   { echo -e "${VERT}[OK]${RESET}    $1"; }
info() { echo -e "${BLEU}[INFO]${RESET}  $1"; }
warn() { echo -e "${JAUNE}[WARN]${RESET}  $1"; }
fail() { echo -e "${ROUGE}[ERREUR]${RESET} $1"; exit 1; }

# ─── VÉRIFICATION DU RÉSEAU DE BASE (TP0) ────────────────────────────────────
info "Vérification que le réseau TP0 est bien déployé..."
for ns in PC1 PC2 GATEWAY ISP; do
	if ! sudo ip netns list | grep -q "^${ns}"; then
		fail "Namespace $ns manquant — lancez d'abord : bash setup_network.sh"
	fi
done
ok "Réseau TP0 détecté"
echo ""

# ─── ÉTAPE 1 : NETTOYAGE PRÉVENTIF DHCP ──────────────────────────────────────
info "=== ÉTAPE 1 : Nettoyage préventif DHCP ==="

sudo ip netns exec DHCP_SERVER pkill dnsmasq 2>/dev/null && warn "dnsmasq arrêté" || true

sudo rm -f /tmp/dhcp_lan1.conf /tmp/dhcp_lan2.conf \
    /tmp/dnsmasq.log /tmp/dnsmasq.pid \
    /var/lib/misc/dnsmasq.leases 2>/dev/null || true

sudo ip link delete dhcp_pc1 2>/dev/null && warn "Interface dhcp_pc1 supprimée" || true
sudo ip link delete dhcp_pc2 2>/dev/null && warn "Interface dhcp_pc2 supprimée" || true

sudo ip netns del DHCP_SERVER 2>/dev/null && warn "Namespace DHCP_SERVER supprimé" || true

ok "Nettoyage DHCP terminé"
echo ""

# ─── ÉTAPE 2 : CRÉATION DU NAMESPACE DHCP_SERVER ─────────────────────────────
info "=== ÉTAPE 2 : Création du namespace DHCP_SERVER ==="

sudo ip netns add DHCP_SERVER
ok "Namespace DHCP_SERVER créé"
echo ""

# ─── ÉTAPE 3 : CRÉATION DES PAIRES VETH ──────────────────────────────────────
info "=== ÉTAPE 3 : Création des liens virtuels (veth pairs) ==="

sudo ip link add dhcp_pc1 type veth peer name dhcp1
ok "dhcp_pc1 <-> dhcp1 (PC1 <-> DHCP_SERVER / LAN1)"

sudo ip link add dhcp_pc2 type veth peer name dhcp2
ok "dhcp_pc2 <-> dhcp2 (PC2 <-> DHCP_SERVER / LAN2)"
echo ""

# ─── ÉTAPE 4 : ASSIGNATION AUX NAMESPACES ────────────────────────────────────
info "=== ÉTAPE 4 : Assignation des interfaces aux namespaces ==="

sudo ip link set dhcp1   netns DHCP_SERVER && ok "dhcp1    -> DHCP_SERVER"
sudo ip link set dhcp2   netns DHCP_SERVER && ok "dhcp2    -> DHCP_SERVER"
sudo ip link set dhcp_pc1 netns PC1        && ok "dhcp_pc1 -> PC1"
sudo ip link set dhcp_pc2 netns PC2        && ok "dhcp_pc2 -> PC2"
echo ""

# ─── ÉTAPE 5 : ACTIVATION DES INTERFACES ─────────────────────────────────────
info "=== ÉTAPE 5 : Activation des interfaces ==="

sudo ip netns exec DHCP_SERVER ip link set dhcp1 up && ok "DHCP_SERVER/dhcp1 UP"
sudo ip netns exec DHCP_SERVER ip link set dhcp2 up && ok "DHCP_SERVER/dhcp2 UP"
sudo ip netns exec DHCP_SERVER ip link set lo    up && ok "DHCP_SERVER/lo UP"

sudo ip netns exec PC1 ip link set dhcp_pc1 up && ok "PC1/dhcp_pc1 UP"
sudo ip netns exec PC2 ip link set dhcp_pc2 up && ok "PC2/dhcp_pc2 UP"
echo ""

# ─── ÉTAPE 6 : ADRESSAGE IP DU SERVEUR DHCP ──────────────────────────────────
info "=== ÉTAPE 6 : Configuration IP du serveur DHCP ==="

sudo ip netns exec DHCP_SERVER ip addr add 192.168.10.1/24 dev dhcp1
ok "DHCP_SERVER : dhcp1 = 192.168.10.1/24 (passerelle LAN1)"

sudo ip netns exec DHCP_SERVER ip addr add 192.168.20.1/24 dev dhcp2
ok "DHCP_SERVER : dhcp2 = 192.168.20.1/24 (passerelle LAN2)"

sudo ip netns exec DHCP_SERVER ip link set dhcp1 up
sudo ip netns exec DHCP_SERVER ip link set dhcp2 up
sudo ip netns exec DHCP_SERVER ip link set lo    up
echo ""

# ─── ÉTAPE 7 : INSTALLATION DE DNSMASQ ───────────────────────────────────────
info "=== ÉTAPE 7 : Vérification / Installation de dnsmasq ==="

sudo ip netns exec DHCP_SERVER bash -c \
    "command -v dnsmasq >/dev/null 2>&1 || (apt-get update -qq && apt-get install -y -qq dnsmasq)"
DNSMASQ_VER=$(sudo ip netns exec DHCP_SERVER dnsmasq --version 2>&1 | head -1)
ok "dnsmasq disponible : $DNSMASQ_VER"
echo ""

# ─── ÉTAPE 8 : CONFIGURATION DHCP LAN1 ───────────────────────────────────────
info "=== ÉTAPE 8 : Configuration DHCP pour LAN1 ==="

sudo ip netns exec DHCP_SERVER bash -c 'cat > /tmp/dhcp_lan1.conf <<EOF
# Configuration DHCP — LAN1 (192.168.10.0/24)
interface=dhcp1
dhcp-range=192.168.10.50,192.168.10.100,12h
dhcp-option=3,192.168.10.1
EOF'
ok "Fichier /tmp/dhcp_lan1.conf créé"
echo "    Pool : 192.168.10.50 - 192.168.10.100 | Passerelle : 192.168.10.1 | Bail : 12h"
echo ""

# ─── ÉTAPE 9 : CONFIGURATION DHCP LAN2 ───────────────────────────────────────
info "=== ÉTAPE 9 : Configuration DHCP pour LAN2 ==="

sudo ip netns exec DHCP_SERVER bash -c 'cat > /tmp/dhcp_lan2.conf <<EOF
# Configuration DHCP — LAN2 (192.168.20.0/24)
interface=dhcp2
dhcp-range=192.168.20.50,192.168.20.100,12h
dhcp-option=3,192.168.20.1
EOF'
ok "Fichier /tmp/dhcp_lan2.conf créé"
echo "    Pool : 192.168.20.50 - 192.168.20.100 | Passerelle : 192.168.20.1 | Bail : 12h"
echo ""

# ─── ÉTAPE 10 : LANCEMENT DU SERVICE DHCP ────────────────────────────────────
info "=== ÉTAPE 10 : Lancement du service DHCP (dnsmasq) ==="

sudo ip netns exec DHCP_SERVER pkill dnsmasq 2>/dev/null || true
sleep 1

sudo rm -f /tmp/dnsmasq.log /tmp/dnsmasq.pid 2>/dev/null || true
sudo touch /tmp/dnsmasq.log /tmp/dnsmasq.pid
sudo chmod 666 /tmp/dnsmasq.log /tmp/dnsmasq.pid

sudo ip netns exec DHCP_SERVER dnsmasq \
    --conf-file=/tmp/dhcp_lan1.conf \
    --conf-file=/tmp/dhcp_lan2.conf \
    --conf-dir= \
    --log-facility=/tmp/dnsmasq.log \
    --pid-file=/tmp/dnsmasq.pid &

sleep 2

if sudo ip netns exec DHCP_SERVER ps aux 2>/dev/null | grep -q '[d]nsmasq'; then
    ok "dnsmasq en cours d'exécution (LAN1 + LAN2)"
else
    fail "dnsmasq ne s'est pas lancé — vérifiez les fichiers de configuration"
fi
echo ""

# ─── ÉTAPE 11 : DÉTECTION DU CLIENT DHCP ─────────────────────────────────────
info "=== ÉTAPE 11 : Détection du client DHCP ==="

DHCP_CLIENT=""
for candidate in dhclient dhcpcd udhcpc; do
    if command -v "$candidate" &>/dev/null; then
        DHCP_CLIENT="$candidate"
        ok "Client DHCP détecté : $candidate"
        break
    fi
done

if [ -z "$DHCP_CLIENT" ]; then
    warn "Aucun client DHCP trouvé — installation de dhcpcd..."
    sudo apt-get install -y -qq dhcpcd5 2>/dev/null || \
    sudo apt-get install -y -qq isc-dhcp-client 2>/dev/null || \
        fail "Impossible d'installer un client DHCP"
    DHCP_CLIENT="dhcpcd"
    ok "dhcpcd installé"
fi
echo ""

# ─── ÉTAPE 12 : DEMANDE D'ADRESSE IP VIA DHCP ────────────────────────────────
info "=== ÉTAPE 12 : Demande d'adresse IP via DHCP ($DHCP_CLIENT) ==="

sudo ip netns exec PC1 ip addr flush dev dhcp_pc1 2>/dev/null || true
sudo ip netns exec PC2 ip addr flush dev dhcp_pc2 2>/dev/null || true

dhcp_request() {
    local ns="$1" iface="$2"
    case "$DHCP_CLIENT" in
        dhclient) sudo ip netns exec "$ns" dhclient -v "$iface" 2>&1 | tail -5 ;;
        dhcpcd)   sudo ip netns exec "$ns" dhcpcd "$iface"      2>&1 | tail -5 ;;
        udhcpc)   sudo ip netns exec "$ns" udhcpc -i "$iface" -n -q 2>&1 | tail -5 ;;
    esac
}

info "Lancement du client DHCP sur PC1 (dhcp_pc1)..."
dhcp_request PC1 dhcp_pc1 || warn "Client DHCP PC1 : terminé"

info "Lancement du client DHCP sur PC2 (dhcp_pc2)..."
dhcp_request PC2 dhcp_pc2 || warn "Client DHCP PC2 : terminé"

sleep 2

echo ""
for ns in PC1 PC2; do
    iface="dhcp_pc$(echo $ns | grep -oP '\d+')"
    IP=$(sudo ip netns exec "$ns" ip addr show "$iface" 2>/dev/null | grep -oP 'inet \K[\d./]+')
    if [ -n "$IP" ]; then
        ok "$ns a obtenu l'adresse : $IP (via $DHCP_CLIENT)"
    else
        warn "$ns n'a pas encore d'IP — relancez : sudo ip netns exec $ns $DHCP_CLIENT $iface"
    fi
done

echo ""

# ─── RÉSUMÉ ───────────────────────────────────────────────────────────────────
echo -e "${VERT}============================================================${RESET}"
echo -e "${VERT}        Serveur DHCP TP2 déployé avec succès !${RESET}"
echo -e "${VERT}============================================================${RESET}"
echo ""
echo "  DHCP_SERVER :"
echo "    dhcp1 : 192.168.10.1/24  (LAN1 — pool 10.50 à 10.100)"
echo "    dhcp2 : 192.168.20.1/24  (LAN2 — pool 20.50 à 20.100)"
echo ""
echo "  Clients DHCP :"
echo "    PC1 : interface dhcp_pc1 — IP dynamique LAN1"
echo "    PC2 : interface dhcp_pc2 — IP dynamique LAN2"
echo ""
echo "  Pour nettoyer : bash cleanup_dhcp.sh"
echo ""
