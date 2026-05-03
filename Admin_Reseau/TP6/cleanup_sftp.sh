#!/bin/bash
# =============================================================================
# TP6 - Nettoyage du service SFTP
# Préserve : TP0, TP3, TP4, TP5 (WEB namespace + Apache HTTPS restent intacts)
# Supprime : sshd dans WEB, utilisateur sftpuser, config SSH TP6
# Auteur : HATHOUTI Mohammed Taha
# =============================================================================

VERT="\e[32m"; ROUGE="\e[31m"; JAUNE="\e[33m"; BLEU="\e[34m"; RESET="\e[0m"
info() { echo -e "${BLEU}[INFO]${RESET}   $1"; }
ok()   { echo -e "${VERT}[OK]${RESET}     $1"; }
warn() { echo -e "${JAUNE}[SKIP]${RESET}   $1 (inexistant)"; }

echo ""
info "=== NETTOYAGE SFTP — TP6 (WEB + DNS + TP0 + TP3 + TP5 préservés) ==="
echo ""

# ─── ARRÊT DE SSHD DANS LE NAMESPACE WEB ─────────────────────────────────────
info "Arrêt de sshd dans le namespace WEB..."
if sudo ip netns list 2>/dev/null | grep -q "^WEB"; then
	sudo ip netns exec WEB pkill sshd 2>/dev/null && ok "sshd arrêté dans WEB" || warn "sshd"
else
	warn "WEB (namespace absent)"
fi

# ─── SUPPRESSION DE L'UTILISATEUR SFTP ───────────────────────────────────────
info "Suppression de l'utilisateur sftpuser..."
if id sftpuser &>/dev/null; then
	sudo pkill -u sftpuser 2>/dev/null || true   # tuer les processus résiduels
	sleep 1
	sudo deluser --remove-home sftpuser 2>/dev/null \
		&& ok "Utilisateur sftpuser et répertoire /home/sftpuser supprimés" \
		|| warn "deluser sftpuser"
else
	warn "sftpuser (utilisateur absent)"
fi

# ─── SUPPRESSION DU RÉPERTOIRE /run/sshd ─────────────────────────────────────
info "Suppression du répertoire /run/sshd..."
sudo rm -rf /run/sshd 2>/dev/null && ok "/run/sshd supprimé" || warn "/run/sshd"

# ─── NETTOYAGE DE LA CONFIGURATION SSH ───────────────────────────────────────
info "Suppression du bloc Match User sftpuser dans /etc/ssh/sshd_config..."

if grep -q "Match User sftpuser" /etc/ssh/sshd_config 2>/dev/null; then
	sudo sed -i '/^# Configuration SFTP/,/^X11Forwarding no$/d' /etc/ssh/sshd_config 2>/dev/null || true
	sudo sed -i '/^Match User sftpuser/,/^X11Forwarding no$/d' /etc/ssh/sshd_config 2>/dev/null || true
	# Supprimer les lignes vides résiduelles en fin de fichier
	sudo sed -i -e :a -e '/^\s*$/{$d;N;ba}' /etc/ssh/sshd_config 2>/dev/null || true
	ok "Bloc Match User sftpuser supprimé de sshd_config"
else
	warn "Bloc Match User sftpuser (déjà absent)"
fi

# Restaurer la sauvegarde si disponible et si sshd_config est corrompu
if [ -f /etc/ssh/sshd_config.bak.tp6 ]; then
	info "Sauvegarde disponible : /etc/ssh/sshd_config.bak.tp6"
	ok "Pour restaurer : sudo cp /etc/ssh/sshd_config.bak.tp6 /etc/ssh/sshd_config"
fi

# ─── VÉRIFICATION QUE TP5 EST INTACT (APACHE HTTPS TOUJOURS ACTIF) ───────────
echo ""
info "Vérification que le namespace WEB et Apache HTTPS sont toujours actifs..."

if sudo ip netns list 2>/dev/null | grep -q "^WEB"; then
	ok "Namespace WEB : présent"
	if sudo ip netns exec WEB ss -tulnp 2>/dev/null | grep -q ':443'; then
		ok "Apache HTTPS (port 443) : toujours actif"
	else
		warn "Apache HTTPS non détecté — relancez : bash enable_https.sh"
	fi
else
	warn "WEB (namespace absent)"
fi

# ─── VÉRIFICATION QUE TP0 + TP4 SONT INTACTS ─────────────────────────────────
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

echo ""
echo -e "${VERT}=================================================================${RESET}"
echo -e "${VERT}  Nettoyage SFTP terminé. TP0 + TP3 + TP4 + TP5 préservés.${RESET}"
echo -e "${VERT}=================================================================${RESET}"
echo ""
if $ALL_OK; then
	echo -e "  ${VERT}Environnement intact. Pour redéployer SFTP :${RESET}"
	echo -e "    ${JAUNE}bash enable_sftp.sh${RESET}"
else
	echo -e "  ${ROUGE}Certains namespaces manquent. Relancez depuis TP0 :${RESET}"
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
