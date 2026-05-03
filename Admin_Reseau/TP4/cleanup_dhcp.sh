#!/bin/bash
# =============================================================================
# TP2 - Script de nettoyage et réinitialisation DHCP uniquement
# Préserve le réseau TP0 (PC1, PC2, GATEWAY, ISP)
# Auteur : HATHOUTI Mohammed Taha
# =============================================================================

VERT="\e[32m"; JAUNE="\e[33m"; BLEU="\e[34m"; ROUGE="\e[31m"; RESET="\e[0m"
info() { echo -e "${BLEU}[INFO]${RESET}  $1"; }
ok()   { echo -e "${VERT}[OK]${RESET}    $1"; }
warn() { echo -e "${JAUNE}[SKIP]${RESET}  $1 (inexistant)"; }

echo ""
info "=== NETTOYAGE DHCP — TP2 (réseau TP0 préservé) ==="
echo ""

# ─── ARRÊT DU SERVICE DHCP ───────────────────────────────────────────────────
info "Arrêt du service dnsmasq dans DHCP_SERVER..."
if sudo ip netns list 2>/dev/null | grep -q "^DHCP_SERVER"; then
    sudo ip netns exec DHCP_SERVER pkill dnsmasq 2>/dev/null && ok "dnsmasq arrêté" || warn "dnsmasq"
else
    warn "DHCP_SERVER (namespace inexistant)"
fi

# ─── SUPPRESSION DES FICHIERS DE CONFIGURATION ET DE BAUX ────────────────────
info "Suppression des fichiers de configuration et de baux DHCP..."

sudo ip netns exec DHCP_SERVER rm -f \
    /tmp/dhcp_lan1.conf \
    /tmp/dhcp_lan2.conf \
    /tmp/dnsmasq.log \
    /tmp/dnsmasq.pid \
    /var/lib/misc/dnsmasq.leases 2>/dev/null && ok "Fichiers DHCP supprimés (namespace)" || true

for f in /tmp/dhcp_lan1.conf /tmp/dhcp_lan2.conf /tmp/dnsmasq.log /tmp/dnsmasq.pid /var/lib/misc/dnsmasq.leases; do
    if [ -f "$f" ]; then
        sudo rm -f "$f" && ok "Supprimé (hôte) : $f"
    else
        warn "$f"
    fi
done

for f in /var/lib/dhcp/dhclient.leases /var/lib/dhclient/dhclient.leases; do
    sudo ip netns exec PC1 rm -f "$f" 2>/dev/null || true
    sudo ip netns exec PC2 rm -f "$f" 2>/dev/null || true
done
ok "Fichiers de baux dhclient supprimés sur PC1 et PC2"

# ─── LIBÉRATION DES BAUX DHCP CÔTÉ CLIENTS ───────────────────────────────────
info "Libération des baux DHCP sur PC1 et PC2..."

sudo ip netns exec PC1 dhclient -r dhcp_pc1 2>/dev/null && ok "Bail libéré sur PC1 (dhcp_pc1)" || warn "dhclient PC1"
sudo ip netns exec PC2 dhclient -r dhcp_pc2 2>/dev/null && ok "Bail libéré sur PC2 (dhcp_pc2)" || warn "dhclient PC2"

sudo ip netns exec PC1 ip addr flush dev dhcp_pc1 2>/dev/null && ok "Adresses vidées sur PC1/dhcp_pc1" || warn "flush PC1"
sudo ip netns exec PC2 ip addr flush dev dhcp_pc2 2>/dev/null && ok "Adresses vidées sur PC2/dhcp_pc2" || warn "flush PC2"

# ─── SUPPRESSION DES INTERFACES VETH DHCP ────────────────────────────────────
info "Suppression des interfaces veth liées au DHCP..."

for lien in dhcp_pc1 dhcp_pc2; do
    if sudo ip link show "$lien" &>/dev/null 2>&1; then
        sudo ip link del "$lien" 2>/dev/null && ok "Interface $lien supprimée"
    else
        warn "$lien"
    fi
done

for iface in dhcp1 dhcp2; do
    sudo ip netns exec DHCP_SERVER ip link del "$iface" 2>/dev/null && ok "$iface supprimée (namespace DHCP_SERVER)" || true
done
for iface in dhcp_pc1 dhcp_pc2; do
    sudo ip netns exec PC1 ip link del "$iface" 2>/dev/null || true
    sudo ip netns exec PC2 ip link del "$iface" 2>/dev/null || true
done

# ─── SUPPRESSION DU NAMESPACE DHCP_SERVER ────────────────────────────────────
info "Suppression du namespace DHCP_SERVER..."
if sudo ip netns list 2>/dev/null | grep -q "^DHCP_SERVER"; then
    sudo ip netns del DHCP_SERVER && ok "Namespace DHCP_SERVER supprimé"
else
    warn "DHCP_SERVER"
fi

# ─── VÉRIFICATION QUE TP0 EST INTACT ─────────────────────────────────────────
echo ""
info "Vérification que le réseau TP0 est toujours intact..."
ALL_OK=true
for ns in PC1 PC2 GATEWAY ISP; do
    if sudo ip netns list 2>/dev/null | grep -q "^${ns}"; then
        ok "Namespace $ns : présent"
    else
        echo -e "${ROUGE}[ERREUR]${RESET} Namespace $ns MANQUANT — le réseau TP0 semble endommagé !"
        ALL_OK=false
    fi
done

echo ""
echo -e "${VERT}=================================================================${RESET}"
echo -e "${VERT}  Nettoyage DHCP terminé. Réseau TP0 préservé.${RESET}"
echo -e "${VERT}=================================================================${RESET}"
echo ""
if $ALL_OK; then
    echo -e "  ${VERT}Le réseau de base TP0 est intact.${RESET}"
    echo -e "  Vous pouvez relancer : ${JAUNE}bash setup_dhcp.sh${RESET}"
else
    echo -e "  ${ROUGE}Attention : certains namespaces TP0 manquent.${RESET}"
    echo -e "  Relancez d'abord : ${JAUNE}bash setup_network.sh${RESET}"
fi
echo ""

info "Namespaces actifs après nettoyage :"
REMAINING=$(sudo ip netns list 2>/dev/null)
if [ -z "$REMAINING" ]; then
    echo "  (aucun)"
else
    echo "$REMAINING" | sed 's/^/  /'
fi
echo ""
