#!/bin/bash
# =============================================================================
# TP6 - Déploiement du service SFTP sécurisé (OpenSSH)
# Auteur : HATHOUTI Mohammed Taha
#
# Prérequis :
#   - setup_network.sh     (TP0) exécuté
#   - enable_static_nat.sh (TP3) exécuté
#   - enable_dns.sh        (TP4) exécuté
#   - enable_webserver.sh  (TP5) exécuté  → namespace WEB opérationnel
#   - enable_https.sh      (TP5) exécuté  → Apache HTTPS sur port 443
#
# Ce script :
#   1. Vérifie que le namespace WEB et HTTPS sont opérationnels
#   2. Installe OpenSSH Server (filesystem partagé hôte/namespace)
#   3. Crée l'utilisateur SFTP dédié (sftpuser) avec chroot sécurisé
#   4. Configure SSH pour accès SFTP uniquement (ForceCommand internal-sftp)
#   5. Démarre sshd dans le namespace WEB
#   6. Teste upload/download depuis PC1 et PC2
# =============================================================================

# NE PAS utiliser set -e globalement — les tests SFTP peuvent échouer
# sans que ce soit critique ; on gère les erreurs manuellement

VERT="\e[32m"; ROUGE="\e[31m"; JAUNE="\e[33m"; BLEU="\e[34m"; RESET="\e[0m"
ok()   { echo -e "${VERT}[OK]${RESET}     $1"; }
info() { echo -e "${BLEU}[INFO]${RESET}   $1"; }
warn() { echo -e "${JAUNE}[WARN]${RESET}   $1"; }
fail() { echo -e "${ROUGE}[ERREUR]${RESET} $1"; exit 1; }

# ─── VARIABLES ────────────────────────────────────────────────────────────────
SFTP_USER="sftpuser"
SFTP_PASS="Lab12345"          # Min 8 caractères pour éviter l'avertissement PAM
WEB_NS="WEB"
SFTP_HOME="/home/${SFTP_USER}"
SFTP_DIR="${SFTP_HOME}/files"
WEB_IP="192.168.40.2"

echo ""
echo -e "${VERT}============================================${RESET}"
echo -e "${VERT}  TP6 - Déploiement SFTP${RESET}"
echo -e "${VERT}============================================${RESET}"
echo ""

# ─── ÉTAPE 1 : VÉRIFICATION DES PRÉREQUIS ────────────────────────────────────
info "=== ÉTAPE 1 : Vérification des prérequis (TP0 → TP5) ==="

for ns in PC1 PC2 GATEWAY ISP DNS WEB; do
	if ! sudo ip netns list | grep -q "^${ns}"; then
		fail "Namespace $ns manquant — exécutez les scripts précédents dans l'ordre :\n  setup_network.sh → enable_static_nat.sh → enable_dns.sh → enable_webserver.sh → enable_https.sh"
	fi
done

# Vérifier qu'Apache tourne sur port 443 dans WEB
if ! sudo ip netns exec WEB ss -tulnp 2>/dev/null | grep -q ':443'; then
	fail "Apache HTTPS non actif dans WEB — lancez d'abord : bash enable_https.sh"
fi

ok "Tous les prérequis sont satisfaits (TP0 → TP5)"
echo ""

# ─── ÉTAPE 2 : INSTALLATION DE OPENSSH-SERVER ────────────────────────────────
info "=== ÉTAPE 2 : Vérification / Installation de OpenSSH Server ==="

# Le filesystem est partagé entre l'hôte et les namespaces : on installe sur l'hôte
if ! which sshd >/dev/null 2>&1; then
	warn "sshd non trouvé — installation en cours..."
	sudo apt-get update -qq && sudo apt-get install -y -qq openssh-server
fi

SSHD_VER=$(sshd -V 2>&1 | head -1)
ok "OpenSSH Server disponible : $SSHD_VER"
echo ""

# ─── ÉTAPE 3 : CRÉATION DE L'UTILISATEUR SFTP ────────────────────────────────
info "=== ÉTAPE 3 : Création de l'utilisateur SFTP (${SFTP_USER}) ==="

if id "${SFTP_USER}" &>/dev/null; then
	warn "L'utilisateur ${SFTP_USER} existe déjà — mise à jour du mot de passe"
else
	sudo adduser --gecos "" --disabled-password "${SFTP_USER}"
	ok "Utilisateur ${SFTP_USER} créé"
fi

echo "${SFTP_USER}:${SFTP_PASS}" | sudo chpasswd
ok "Mot de passe configuré pour ${SFTP_USER}"
echo ""

# ─── ÉTAPE 4 : CONFIGURATION DU CHROOT DIRECTORY ─────────────────────────────
info "=== ÉTAPE 4 : Configuration du chroot et des répertoires ==="

sudo mkdir -p "${SFTP_DIR}"

# Le répertoire home DOIT appartenir à root (règle chroot OpenSSH)
sudo chown root:root "${SFTP_HOME}"
sudo chmod 755 "${SFTP_HOME}"
ok "Chroot : ${SFTP_HOME} → root:root 755"

# Le répertoire files appartient à sftpuser (lecture/écriture)
sudo chown "${SFTP_USER}:${SFTP_USER}" "${SFTP_DIR}"
sudo chmod 700 "${SFTP_DIR}"
ok "Upload : ${SFTP_DIR} → ${SFTP_USER}:${SFTP_USER} 700"
echo ""

# ─── ÉTAPE 5 : CONFIGURATION SSH POUR SFTP UNIQUEMENT ────────────────────────
info "=== ÉTAPE 5 : Configuration SSH (SFTP only pour ${SFTP_USER}) ==="

# Sauvegarder la configuration existante
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.tp6 2>/dev/null || true
ok "Sauvegarde : /etc/ssh/sshd_config.bak.tp6"

# Supprimer toute configuration sftpuser résiduelle pour éviter les doublons
sudo sed -i '/^# Configuration SFTP/,/^X11Forwarding no$/d' /etc/ssh/sshd_config 2>/dev/null || true
sudo sed -i '/^Match User sftpuser/,/^X11Forwarding no$/d' /etc/ssh/sshd_config 2>/dev/null || true

# Ajouter le bloc Match User
sudo bash -c "cat >> /etc/ssh/sshd_config << 'EOF'

# Configuration SFTP — TP6 HATHOUTI Mohammed Taha
Match User sftpuser
	ChrootDirectory /home/sftpuser
	ForceCommand internal-sftp
	AllowTcpForwarding no
	X11Forwarding no
	PasswordAuthentication yes
EOF"

ok "Bloc Match User sftpuser ajouté dans /etc/ssh/sshd_config"
echo ""

# ─── ÉTAPE 6 : GÉNÉRATION DES CLÉS HÔTES SSH ─────────────────────────────────
info "=== ÉTAPE 6 : Génération des clés hôtes SSH (si absentes) ==="

if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
	sudo ssh-keygen -A >/dev/null 2>&1
	ok "Clés hôtes SSH générées"
else
	ok "Clés hôtes SSH déjà présentes"
fi
echo ""

# ─── ÉTAPE 7 : DÉMARRAGE DE SSHD DANS LE NAMESPACE WEB ──────────────────────
info "=== ÉTAPE 7 : Démarrage de sshd dans le namespace WEB ==="

# Créer le répertoire /run/sshd requis
sudo ip netns exec "${WEB_NS}" mkdir -p /run/sshd

# Arrêter sshd s'il tourne déjà dans le namespace
sudo ip netns exec "${WEB_NS}" pkill sshd 2>/dev/null && warn "sshd précédent arrêté" || true
sleep 1

# Démarrer sshd dans le namespace WEB
sudo ip netns exec "${WEB_NS}" /usr/sbin/sshd -f /etc/ssh/sshd_config
sleep 2

if sudo ip netns exec "${WEB_NS}" ss -tulnp 2>/dev/null | grep -q ':22'; then
	ok "sshd démarré — écoute sur le port 22 dans le namespace WEB"
else
	fail "sshd n'a pas démarré correctement\n  Debug : sudo ip netns exec WEB /usr/sbin/sshd -d"
fi
echo ""

# ─── ÉTAPE 8 : VÉRIFICATION DES SERVICES EN ÉCOUTE ───────────────────────────
info "=== ÉTAPE 8 : Vérification des ports en écoute dans WEB ==="

echo ""
echo -e "  ${JAUNE}Ports en écoute dans le namespace WEB :${RESET}"
sudo ip netns exec "${WEB_NS}" ss -tulnp 2>/dev/null | grep -E ':22|:80|:443' | sed 's/^/    /'
echo ""

# ─── ÉTAPE 9 : INSTALLATION DE SSHPASS POUR LES TESTS ───────────────────────
info "=== ÉTAPE 9 : Installation de sshpass (tests automatiques) ==="

SSHPASS_OK=false
if which sshpass >/dev/null 2>&1; then
	ok "sshpass disponible"
	SSHPASS_OK=true
else
	warn "sshpass non installé — installation en cours..."
	sudo apt-get install -y -qq sshpass 2>/dev/null && SSHPASS_OK=true \
		|| warn "sshpass non disponible — tests manuels uniquement"
fi
echo ""

# ─── ÉTAPE 10 : TESTS SFTP ────────────────────────────────────────────────────
info "=== ÉTAPE 10 : Tests SFTP depuis PC1 et PC2 ==="
echo ""

if $SSHPASS_OK; then

	# Test 1 : Upload depuis PC1 par IP
	echo -e "  ${JAUNE}Test 1 : Upload depuis PC1 (par IP)...${RESET}"
	sudo ip netns exec PC1 bash -c \
		"echo 'Hello from PC1 via SFTP - TP6 HATHOUTI' > /tmp/test_upload_pc1.txt"

	sudo ip netns exec PC1 bash -c \
		"sshpass -p '${SFTP_PASS}' sftp \
		-o StrictHostKeyChecking=no \
		-o BatchMode=no \
		${SFTP_USER}@${WEB_IP} << 'SFTPEOF'
put /tmp/test_upload_pc1.txt files/test_upload_pc1.txt
ls files/
quit
SFTPEOF" 2>/dev/null

	if [ $? -eq 0 ]; then
		ok "Upload depuis PC1 par IP : réussi"
	else
		warn "Upload depuis PC1 par IP : ÉCHEC"
	fi

	# Test 2 : Vérifier la présence du fichier sur le serveur
	if [ -f "${SFTP_DIR}/test_upload_pc1.txt" ]; then
		ok "Fichier test_upload_pc1.txt présent sur le serveur SFTP"
	else
		warn "Fichier non trouvé sur le serveur"
	fi
	echo ""

	# Test 3 : Download depuis PC2 par IP
	echo -e "  ${JAUNE}Test 2 : Download depuis PC2 (par IP)...${RESET}"
	sudo ip netns exec PC2 bash -c \
		"sshpass -p '${SFTP_PASS}' sftp \
		-o StrictHostKeyChecking=no \
		${SFTP_USER}@${WEB_IP} << 'SFTPEOF'
get files/test_upload_pc1.txt /tmp/test_download_pc2.txt
quit
SFTPEOF" 2>/dev/null

	if [ $? -eq 0 ]; then
		ok "Download depuis PC2 par IP : réussi"
	else
		warn "Download depuis PC2 par IP : ÉCHEC"
	fi
	echo ""

	# Test 4 : Connexion par DNS (web.lab.test)
	echo -e "  ${JAUNE}Test 3 : Connexion par DNS (web.lab.test)...${RESET}"
	sudo ip netns exec PC1 bash -c \
		"sshpass -p '${SFTP_PASS}' sftp \
		-o StrictHostKeyChecking=no \
		${SFTP_USER}@web.lab.test << 'SFTPEOF'
ls files/
quit
SFTPEOF" 2>/dev/null

	if [ $? -eq 0 ]; then
		ok "Connexion par DNS web.lab.test : réussie"
	else
		warn "Connexion par DNS : ÉCHEC — vérifiez la résolution DNS dans PC1"
	fi
	echo ""

	# Test 5 : Upload depuis PC2 par DNS
	echo -e "  ${JAUNE}Test 4 : Upload depuis PC2 par DNS...${RESET}"
	sudo ip netns exec PC2 bash -c \
		"echo 'Hello from PC2 via SFTP - TP6' > /tmp/test_upload_pc2.txt"

	sudo ip netns exec PC2 bash -c \
		"sshpass -p '${SFTP_PASS}' sftp \
		-o StrictHostKeyChecking=no \
		${SFTP_USER}@web.lab.test << 'SFTPEOF'
put /tmp/test_upload_pc2.txt files/test_upload_pc2.txt
ls files/
quit
SFTPEOF" 2>/dev/null

	if [ $? -eq 0 ]; then
		ok "Upload depuis PC2 par DNS : réussi"
	else
		warn "Upload depuis PC2 par DNS : ÉCHEC"
	fi

else
	warn "Tests automatiques ignorés (sshpass indisponible)"
	echo ""
	echo -e "  Connexion manuelle depuis PC1 :"
	echo -e "    sudo ip netns exec PC1 sftp ${SFTP_USER}@${WEB_IP}"
	echo -e "    sudo ip netns exec PC1 sftp ${SFTP_USER}@web.lab.test"
fi

echo ""

# ─── RÉSUMÉ ───────────────────────────────────────────────────────────────────
echo -e "${VERT}============================================================${RESET}"
echo -e "${VERT}       Service SFTP TP6 déployé avec succès !${RESET}"
echo -e "${VERT}============================================================${RESET}"
echo ""
echo "  Namespace    : ${WEB_NS} (cohabite avec Apache HTTPS)"
echo "  IP           : ${WEB_IP}"
echo "  DNS          : web.lab.test"
echo "  Port SFTP    : 22 (SSH)"
echo "  Port HTTPS   : 443 (Apache — toujours actif)"
echo ""
echo "  Utilisateur  : ${SFTP_USER}"
echo "  Mot de passe : ${SFTP_PASS}"
echo "  Chroot       : ${SFTP_HOME} (root:root 755)"
echo "  Upload dir   : ${SFTP_DIR} (${SFTP_USER}:${SFTP_USER} 700)"
echo ""
echo "  Connexion depuis PC1 :"
echo "    sudo ip netns exec PC1 sftp ${SFTP_USER}@web.lab.test"
echo "    sudo ip netns exec PC1 sftp ${SFTP_USER}@${WEB_IP}"
echo ""
echo "  Commandes SFTP :"
echo "    ls                              # lister le répertoire racine"
echo "    cd files                        # entrer dans le répertoire upload"
echo "    put monfichier.txt files/       # upload"
echo "    get files/monfichier.txt        # download"
echo "    exit                            # quitter"
echo ""
echo "  Capture trafic (depuis un autre terminal) :"
echo "    sudo ip netns exec GATEWAY tcpdump -i veth-gw-web port 22 -w sftp.pcap"
echo ""
echo "  Pour nettoyer : bash cleanup_sftp.sh"
echo ""
