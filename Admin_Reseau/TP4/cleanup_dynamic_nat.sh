#!/bin/bash
# =============================================================================
# TP3 - Nettoyage et réinitialisation du NAT Dynamique
# Préserve le réseau TP0 (PC1, PC2, GATEWAY, ISP) et le DHCP TP2
# Auteur : HATHOUTI Mohammed Taha
# =============================================================================

VERT="\e[32m"; JAUNE="\e[33m"; BLEU="\e[34m"; ROUGE="\e[31m"; RESET="\e[0m"
info() { echo -e "${BLEU}[INFO]${RESET}  $1"; }
ok()   { echo -e "${VERT}[OK]${RESET}    $1"; }
warn() { echo -e "${JAUNE}[SKIP]${RESET}  $1 (inexistant ou déjà vide)"; }

echo ""
info "=== NETTOYAGE NAT DYNAMIQUE — TP3 (réseau TP0 + DHCP TP2 préservés) ==="
echo ""

if ! sudo ip netns list 2>/dev/null | grep -q "^GATEWAY"; then
	echo -e "${ROUGE}[ERREUR]${RESET} Namespace GATEWAY introuvable — rien à nettoyer."
	exit 0
fi

# ─── VIDER LES RÈGLES FILTER ─────────────────────────────────────────────────
info "Suppression des règles iptables filter (FORWARD) sur GATEWAY..."
sudo ip netns exec GATEWAY iptables -F \
	&& ok "Chaîne filter vidée (-F)" || warn "iptables -F"

# ─── VIDER LES RÈGLES NAT ────────────────────────────────────────────────────
info "Suppression des règles NAT (POSTROUTING MASQUERADE) sur GATEWAY..."
sudo ip netns exec GATEWAY iptables -t nat -F \
	&& ok "Table NAT vidée (-t nat -F)" || warn "iptables -t nat -F"

# ─── SUPPRIMER LES CHAÎNES PERSONNALISÉES ────────────────────────────────────
info "Suppression des chaînes iptables personnalisées..."
sudo ip netns exec GATEWAY iptables -X \
	&& ok "Chaînes personnalisées supprimées (-X)" || warn "iptables -X"

# ─── REMETTRE LA POLITIQUE FORWARD À ACCEPT ──────────────────────────────────
info "Remise à zéro de la politique FORWARD -> ACCEPT..."
sudo ip netns exec GATEWAY iptables -P FORWARD ACCEPT \
	&& ok "Politique FORWARD -> ACCEPT" || warn "iptables -P FORWARD ACCEPT"

# ─── VIDER LE SUIVI DE CONNEXION ─────────────────────────────────────────────
info "Suppression des entrées conntrack..."
sudo ip netns exec GATEWAY conntrack -F 2>/dev/null \
	&& ok "Table conntrack vidée" \
	|| warn "conntrack -F (non installé ou table déjà vide)"

# ─── VÉRIFICATION QUE TP0 + TP2 SONT INTACTS ─────────────────────────────────
echo ""
info "Vérification que le réseau TP0 et le DHCP TP2 sont toujours intacts..."
ALL_OK=true
for ns in PC1 PC2 GATEWAY ISP; do
	if sudo ip netns list 2>/dev/null | grep -q "^${ns}"; then
		ok "Namespace $ns : présent"
	else
		echo -e "${ROUGE}[ERREUR]${RESET} Namespace $ns MANQUANT"
		ALL_OK=false
	fi
done

if sudo ip netns list 2>/dev/null | grep -q "^DHCP_SERVER"; then
	ok "Namespace DHCP_SERVER : présent"
	if sudo ip netns exec DHCP_SERVER ps aux 2>/dev/null | grep -q '[d]nsmasq'; then
		ok "Service dnsmasq : actif"
	else
		warn "dnsmasq non actif — relancez bash setup_dhcp.sh si nécessaire"
	fi
else
	warn "DHCP_SERVER absent (normal si setup_dhcp.sh non exécuté)"
fi

echo ""
echo -e "${VERT}=================================================================${RESET}"
echo -e "${VERT}  Nettoyage NAT dynamique terminé. Réseau TP0 préservé.${RESET}"
echo -e "${VERT}=================================================================${RESET}"
echo ""
if $ALL_OK; then
	echo -e "  ${VERT}Réseau TP0 intact. Vous pouvez relancer :${RESET}"
	echo -e "    ${JAUNE}bash enable_dynamic_nat.sh${RESET}"
else
	echo -e "  ${ROUGE}Certains namespaces TP0 manquent — relancez :${RESET}"
	echo -e "    ${JAUNE}bash setup_network.sh${RESET}"
fi
echo ""
