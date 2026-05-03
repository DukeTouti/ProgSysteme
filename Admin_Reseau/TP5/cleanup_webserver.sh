#!/bin/bash
# =============================================================================
# TP5 - Nettoyage du serveur Web
# Préserve : TP0 (PC1, PC2, GATEWAY, ISP) + TP3 (NAT) + TP4 (DNS)
# Auteur : HATHOUTI Mohammed Taha
# =============================================================================

VERT="\e[32m"; ROUGE="\e[31m"; JAUNE="\e[33m"; BLEU="\e[34m"; RESET="\e[0m"
info() { echo -e "${BLEU}[INFO]${RESET}   $1"; }
ok()   { echo -e "${VERT}[OK]${RESET}     $1"; }
warn() { echo -e "${JAUNE}[SKIP]${RESET}   $1 (inexistant)"; }

echo ""
info "=== NETTOYAGE SERVEUR WEB — TP5 (TP0 + TP3 + TP4 préservés) ==="
echo ""

# ─── ARRÊT D'APACHE DANS WEB ─────────────────────────────────────────────────
info "Arrêt d'Apache dans le namespace WEB..."
if sudo ip netns list 2>/dev/null | grep -q "^WEB"; then
	sudo ip netns exec WEB pkill apache2 2>/dev/null && ok "apache2 arrêté" || warn "apache2"
else
	warn "WEB (namespace inexistant, apache2 non arrêté)"
fi

# ─── SUPPRESSION DES INTERFACES VETH WEB ─────────────────────────────────────
info "Suppression des interfaces veth liées à WEB..."

for lien in veth-gw-web veth-web; do
	if sudo ip link show "$lien" &>/dev/null 2>&1; then
		sudo ip link del "$lien" 2>/dev/null && ok "Interface $lien supprimée (hôte)"
	else
		warn "$lien (hôte)"
	fi
done

sudo ip netns exec WEB     ip link del veth-web     2>/dev/null && ok "veth-web supprimée (namespace WEB)"     || true
sudo ip netns exec GATEWAY ip link del veth-gw-web  2>/dev/null && ok "veth-gw-web supprimée (namespace GATEWAY)" || true

# ─── SUPPRESSION DU NAMESPACE WEB ────────────────────────────────────────────
info "Suppression du namespace WEB..."
if sudo ip netns list 2>/dev/null | grep -q "^WEB"; then
	sudo ip netns del WEB && ok "Namespace WEB supprimé"
else
	warn "WEB"
fi

# ─── SUPPRESSION DE LA RÈGLE NAT POUR 192.168.40.0/24 ───────────────────────
info "Suppression de la règle MASQUERADE pour 192.168.40.0/24..."
if sudo ip netns list 2>/dev/null | grep -q "^GATEWAY"; then
	sudo ip netns exec GATEWAY iptables -t nat -D POSTROUTING \
		-s 192.168.40.0/24 -o veth3 -j MASQUERADE 2>/dev/null \
		&& ok "Règle MASQUERADE 192.168.40.0/24 supprimée" \
		|| warn "Règle MASQUERADE 192.168.40.0/24 (déjà absente)"
else
	warn "GATEWAY (namespace absent)"
fi

# ─── SUPPRESSION DE LA ROUTE ISP POUR 192.168.40.0/24 ───────────────────────
info "Suppression de la route ISP pour 192.168.40.0/24..."
if sudo ip netns list 2>/dev/null | grep -q "^ISP"; then
	sudo ip netns exec ISP ip route del 192.168.40.0/24 2>/dev/null \
		&& ok "Route ISP 192.168.40.0/24 supprimée" \
		|| warn "Route ISP 192.168.40.0/24 (déjà absente)"
else
	warn "ISP (namespace absent)"
fi

# ─── SUPPRESSION DES ROUTES WEB SUR PC1 ET PC2 ───────────────────────────────
info "Suppression des routes vers 192.168.40.0/24 sur PC1 et PC2..."
for ns in PC1 PC2; do
	if sudo ip netns list 2>/dev/null | grep -q "^${ns}"; then
		sudo ip netns exec $ns ip route del 192.168.40.0/24 2>/dev/null \
			&& ok "Route 192.168.40.0/24 supprimée sur $ns" \
			|| warn "Route 192.168.40.0/24 sur $ns"
	else
		warn "$ns (namespace absent)"
	fi
done

# ─── SUPPRESSION DES FICHIERS APACHE LIÉS AU TP5 ────────────────────────────
info "Suppression des fichiers Apache (SSL + VirtualHost)..."

for f in \
	/etc/apache2/ssl/web.lab.test.key \
	/etc/apache2/ssl/web.lab.test.crt \
	/etc/apache2/sites-available/web-ssl.conf \
	/etc/apache2/sites-enabled/web-ssl.conf
do
	if [ -f "$f" ]; then
		sudo rm -f "$f" && ok "Supprimé : $f"
	else
		warn "$f"
	fi
done

# Réactiver le site HTTP par défaut si nécessaire
sudo a2ensite 000-default.conf >/dev/null 2>&1 && ok "Site HTTP 000-default.conf réactivé" || true
sudo a2dismod ssl >/dev/null 2>&1 && ok "Module ssl désactivé" || true

# ─── SUPPRESSION DES FICHIERS DE ZONE DNS LAB.TEST ───────────────────────────
info "Suppression du fichier de zone DNS lab.test..."
if [ -f /etc/bind/db.lab.test ]; then
	sudo rm -f /etc/bind/db.lab.test && ok "Supprimé : /etc/bind/db.lab.test"
else
	warn "/etc/bind/db.lab.test"
fi

# ─── VÉRIFICATION QUE TP0 + TP4 SONT INTACTS ─────────────────────────────────
echo ""
info "Vérification que TP0 et TP4 sont toujours intacts..."
ALL_OK=true
for ns in PC1 PC2 GATEWAY ISP DNS; do
	if sudo ip netns list 2>/dev/null | grep -q "^${ns}"; then
		ok "Namespace $ns : présent"
	else
		echo -e "${ROUGE}[ERREUR]${RESET} Namespace $ns MANQUANT"
		ALL_OK=false
	fi
done

# Vérifier que named tourne encore
if sudo ip netns exec DNS pgrep named >/dev/null 2>&1; then
	ok "named (DNS) : toujours actif"
else
	warn "named ne tourne plus — relancez : bash enable_dns.sh"
fi

echo ""
echo -e "${VERT}=================================================================${RESET}"
echo -e "${VERT}  Nettoyage WEB terminé. TP0 + TP3 + TP4 préservés.${RESET}"
echo -e "${VERT}=================================================================${RESET}"
echo ""
if $ALL_OK; then
	echo -e "  ${VERT}Environnement intact. Pour redéployer :${RESET}"
	echo -e "    ${JAUNE}bash enable_webserver.sh${RESET}"
else
	echo -e "  ${ROUGE}Certains namespaces manquent. Relancez :${RESET}"
	echo -e "    ${JAUNE}bash setup_network.sh${RESET}"
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
