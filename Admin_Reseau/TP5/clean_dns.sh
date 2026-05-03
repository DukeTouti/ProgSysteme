#!/bin/bash
# =============================================================================
# TP4 - Script de nettoyage et réinitialisation DNS uniquement
# Préserve le réseau TP0 (PC1, PC2, GATEWAY, ISP)
# Auteur : HATHOUTI Mohammed Taha
# =============================================================================

VERT="\e[32m"; JAUNE="\e[33m"; BLEU="\e[34m"; ROUGE="\e[31m"; RESET="\e[0m"
info() { echo -e "${BLEU}[INFO]${RESET}   $1"; }
ok()   { echo -e "${VERT}[OK]${RESET}     $1"; }
warn() { echo -e "${JAUNE}[SKIP]${RESET}   $1 (inexistant)"; }

echo ""
info "=== NETTOYAGE DNS — TP4 (réseau TP0 préservé) ==="
echo ""

# ─── ARRÊT DU SERVEUR DNS ────────────────────────────────────────────────────
info "Arrêt du serveur named dans le namespace DNS..."
if sudo ip netns list 2>/dev/null | grep -q "^DNS"; then
	sudo ip netns exec DNS pkill named 2>/dev/null && ok "named arrêté" || warn "named"
else
	warn "DNS (namespace inexistant, named non arrêté)"
fi

# ─── SUPPRESSION DES INTERFACES VETH DNS ─────────────────────────────────────
info "Suppression des interfaces veth liées au DNS..."

# veth-dns est l'extrémité côté DNS — sa suppression retire aussi gw-dns
for lien in veth-dns gw-dns; do
	if sudo ip link show "$lien" &>/dev/null 2>&1; then
		sudo ip link del "$lien" 2>/dev/null && ok "Interface $lien supprimée (hôte)"
	else
		warn "$lien (hôte)"
	fi
done

# Tentatives dans les namespaces (si les interfaces y sont déjà assignées)
sudo ip netns exec DNS     ip link del veth-dns 2>/dev/null && ok "veth-dns supprimée (namespace DNS)"     || true
sudo ip netns exec GATEWAY ip link del gw-dns   2>/dev/null && ok "gw-dns supprimée (namespace GATEWAY)"  || true

# ─── SUPPRESSION DE LA VETH HÔTE ─────────────────────────────────────────────
info "Suppression de la veth hôte (veth-host-dns)..."
sudo ip link del veth-host-dns 2>/dev/null && ok "veth-host-dns supprimée (hôte)" || warn "veth-host-dns"

# Suppression de la règle MASQUERADE hôte pour le namespace DNS
info "Suppression de la règle MASQUERADE hôte pour le namespace DNS..."
IFACE_SORTIE=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'dev \K\S+' | head -1)
sudo iptables -t nat -D POSTROUTING -s 10.200.0.2/32 -o "$IFACE_SORTIE" -j MASQUERADE 2>/dev/null \
	&& ok "MASQUERADE hôte supprimé" || warn "MASQUERADE hôte (déjà absent)"

# ─── SUPPRESSION DU NAMESPACE DNS ────────────────────────────────────────────
info "Suppression du namespace DNS..."
if sudo ip netns list 2>/dev/null | grep -q "^DNS"; then
	sudo ip netns del DNS && ok "Namespace DNS supprimé"
else
	warn "DNS"
fi

# ─── SUPPRESSION DES FICHIERS DE ZONE ET CONFIGURATION BIND ──────────────────
info "Suppression des fichiers BIND (zones + options)..."

for fichier in \
	/etc/bind/db.lab.local \
	/etc/bind/db.192.168.30 \
	/etc/bind/named.conf.local \
	/etc/bind/named.conf.options
do
	if [ -f "$fichier" ]; then
		sudo rm -f "$fichier" && ok "Supprimé : $fichier"
	else
		warn "$fichier"
	fi
done

# ─── NETTOYAGE DES RÉSOLVEURS SUR LES CLIENTS ────────────────────────────────
info "Remise à zéro des résolveurs DNS sur PC1 et PC2..."

for ns in PC1 PC2; do
	if sudo ip netns list 2>/dev/null | grep -q "^${ns}"; then
		sudo ip netns exec "$ns" bash -c '> /etc/resolv.conf' 2>/dev/null \
			&& ok "resolv.conf vidé sur $ns" \
			|| warn "resolv.conf $ns"
	else
		warn "$ns (namespace absent)"
	fi
done

# ─── SUPPRESSION DES ROUTES DNS SUR LES CLIENTS ──────────────────────────────
info "Suppression des routes vers 192.168.30.0/24 sur PC1 et PC2..."

sudo ip netns exec PC1 ip route del 192.168.30.0/24 2>/dev/null \
	&& ok "Route 192.168.30.0/24 supprimée sur PC1" \
	|| warn "Route 192.168.30.0/24 sur PC1"

sudo ip netns exec PC2 ip route del 192.168.30.0/24 2>/dev/null \
	&& ok "Route 192.168.30.0/24 supprimée sur PC2" \
	|| warn "Route 192.168.30.0/24 sur PC2"

# ─── SUPPRESSION DE L'IP gw-dns SUR GATEWAY ──────────────────────────────────
info "Suppression de l'adresse 192.168.30.1/24 sur GATEWAY (gw-dns)..."

sudo ip netns exec GATEWAY ip addr del 192.168.30.1/24 dev gw-dns 2>/dev/null \
	&& ok "192.168.30.1/24 retiré de GATEWAY/gw-dns" \
	|| warn "Adresse 192.168.30.1/24 sur GATEWAY/gw-dns"

# ─── VÉRIFICATION QUE TP0 EST INTACT ─────────────────────────────────────────
echo ""
info "Vérification que le réseau TP0 est toujours intact..."
TOUT_OK=true
for ns in PC1 PC2 GATEWAY ISP; do
	if sudo ip netns list 2>/dev/null | grep -q "^${ns}"; then
		ok "Namespace $ns : présent"
	else
		echo -e "${ROUGE}[ERREUR]${RESET} Namespace $ns MANQUANT — le réseau TP0 semble endommagé !"
		TOUT_OK=false
	fi
done

echo ""
echo -e "${VERT}=================================================================${RESET}"
echo -e "${VERT}  Nettoyage DNS terminé. Réseau TP0 préservé.${RESET}"
echo -e "${VERT}=================================================================${RESET}"
echo ""
if $TOUT_OK; then
	echo -e "  ${VERT}Le réseau de base TP0 est intact.${RESET}"
	echo -e "  Vous pouvez relancer : ${JAUNE}bash enable_dns.sh${RESET}"
else
	echo -e "  ${ROUGE}Attention : certains namespaces TP0 manquent.${RESET}"
	echo -e "  Relancez d'abord : ${JAUNE}bash setup_network.sh${RESET}"
fi
echo ""

info "Namespaces actifs après nettoyage :"
RESTANTS=$(sudo ip netns list 2>/dev/null)
if [ -z "$RESTANTS" ]; then
	echo "  (aucun)"
else
	echo "$RESTANTS" | sed 's/^/  /'
fi
echo ""
