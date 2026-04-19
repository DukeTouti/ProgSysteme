#!/bin/bash
# =============================================================================
# TP5 - Activation HTTPS sur le serveur Web (Apache SSL/TLS)
# Auteur : HATHOUTI Mohammed Taha
#
# Prérequis :
#   - enable_webserver.sh (TP5) exécuté (namespace WEB + Apache HTTP opérationnel)
#
# Ce script :
#   1. Active les modules SSL et headers d'Apache
#   2. Génère un certificat auto-signé pour web.lab.test
#   3. Crée un VirtualHost HTTPS sur le port 443
#   4. Redémarre Apache en mode HTTPS
#   5. Teste l'accès HTTPS depuis WEB, PC1, PC2
# =============================================================================

set -e

VERT="\e[32m"; ROUGE="\e[31m"; JAUNE="\e[33m"; BLEU="\e[34m"; RESET="\e[0m"
ok()   { echo -e "${VERT}[OK]${RESET}     $1"; }
info() { echo -e "${BLEU}[INFO]${RESET}   $1"; }
warn() { echo -e "${JAUNE}[WARN]${RESET}   $1"; }
fail() { echo -e "${ROUGE}[ERREUR]${RESET} $1"; exit 1; }

DOMAIN="web.lab.test"

# ─── VÉRIFICATION DES PRÉREQUIS ──────────────────────────────────────────────
info "Vérification des prérequis (namespace WEB + Apache)..."

for ns in PC1 PC2 GATEWAY DNS WEB; do
	if ! sudo ip netns list | grep -q "^${ns}"; then
		fail "Namespace $ns manquant — lancez d'abord : bash enable_webserver.sh"
	fi
done

if ! sudo ip netns exec WEB ss -tulnp 2>/dev/null | grep -q ':80\|:443'; then
	fail "Apache ne tourne pas dans WEB — lancez d'abord : bash enable_webserver.sh"
fi

ok "Prérequis satisfaits (WEB opérationnel)"
echo ""

# ─── ÉTAPE 1 : ACTIVATION DES MODULES APACHE ─────────────────────────────────
info "=== ÉTAPE 1 : Activation des modules Apache (ssl + headers) ==="

# Installation d'openssl si nécessaire
if ! which openssl >/dev/null 2>&1; then
	warn "openssl non trouvé — installation en cours..."
	sudo apt-get update -qq && sudo apt-get install -y -qq openssl
fi

sudo a2enmod ssl     2>/dev/null && ok "Module ssl activé"     || warn "ssl déjà activé"
sudo a2enmod headers 2>/dev/null && ok "Module headers activé" || warn "headers déjà activé"
echo ""

# ─── ÉTAPE 2 : GÉNÉRATION DU CERTIFICAT AUTO-SIGNÉ ───────────────────────────
info "=== ÉTAPE 2 : Génération du certificat SSL auto-signé ==="

sudo mkdir -p /etc/apache2/ssl

# Supprimer l'ancien certificat si présent
sudo rm -f /etc/apache2/ssl/${DOMAIN}.key /etc/apache2/ssl/${DOMAIN}.crt

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
	-keyout /etc/apache2/ssl/${DOMAIN}.key \
	-out    /etc/apache2/ssl/${DOMAIN}.crt \
	-subj   "/C=MA/ST=Rabat-Sale-Kenitra/L=Rabat/O=UIR/OU=ESIN/CN=${DOMAIN}" \
	2>/dev/null

ok "Clé privée  : /etc/apache2/ssl/${DOMAIN}.key"
ok "Certificat  : /etc/apache2/ssl/${DOMAIN}.crt"
ok "CN=${DOMAIN} | Durée 365 jours | RSA 2048 bits"
echo ""

# ─── ÉTAPE 3 : CRÉATION DU VIRTUALHOST HTTPS ─────────────────────────────────
info "=== ÉTAPE 3 : Création du VirtualHost HTTPS (port 443) ==="

sudo bash -c "cat > /etc/apache2/sites-available/web-ssl.conf <<'APACHEEOF'
<VirtualHost *:443>
	ServerName web.lab.test
	DocumentRoot /var/www/html

	SSLEngine on
	SSLCertificateFile    /etc/apache2/ssl/web.lab.test.crt
	SSLCertificateKeyFile /etc/apache2/ssl/web.lab.test.key

	<Directory /var/www/html>
		AllowOverride All
		Require all granted
	</Directory>

	Header always set Strict-Transport-Security \"max-age=63072000; includeSubDomains; preload\"
	Header always set X-Content-Type-Options \"nosniff\"
	Header always set X-Frame-Options \"DENY\"
</VirtualHost>
APACHEEOF"

ok "VirtualHost HTTPS créé : /etc/apache2/sites-available/web-ssl.conf"
echo ""

# ─── ÉTAPE 4 : MISE À JOUR DE LA PAGE DE TEST ────────────────────────────────
info "=== ÉTAPE 4 : Mise à jour de la page web (mention HTTPS) ==="

sudo bash -c 'cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html lang="fr">
<head><meta charset="UTF-8"><title>TP5 Web Server HTTPS — UIR</title></head>
<body>
  <h1>Serveur Web opérationnel (HTTPS)</h1>
  <p>Namespace : WEB | IP : 192.168.40.2 | Domaine : web.lab.test</p>
  <p>Protocole : HTTPS (TLS) | Certificat auto-signé</p>
  <p>Auteur : HATHOUTI Mohammed Taha — UIR/ESIN 3A Cybersécurité</p>
</body>
</html>
EOF'
ok "Page /var/www/html/index.html mise à jour"
echo ""

# ─── ÉTAPE 5 : ACTIVATION DU SITE SSL ET REDÉMARRAGE APACHE ──────────────────
info "=== ÉTAPE 5 : Activation du site SSL et redémarrage d'Apache ==="

sudo a2ensite web-ssl.conf    2>/dev/null && ok "Site web-ssl.conf activé"
sudo a2dissite 000-default.conf 2>/dev/null && ok "Site HTTP par défaut désactivé" || true

# Arrêt propre d'Apache dans le namespace WEB
sudo ip netns exec WEB pkill apache2 2>/dev/null || true
sleep 1

# Recréer les dossiers runtime si nécessaire
sudo ip netns exec WEB mkdir -p /run/apache2 /var/log/apache2
sudo ip netns exec WEB chown www-data:www-data /run/apache2 /var/log/apache2 2>/dev/null || true

# Démarrage d'Apache dans le namespace WEB
sudo ip netns exec WEB bash -c 'source /etc/apache2/envvars && /usr/sbin/apache2 -k start 2>/dev/null'
sleep 2

if sudo ip netns exec WEB ss -tulnp | grep -q ':443'; then
	ok "Apache démarré — écoute sur le port 443 (HTTPS)"
else
	warn "Apache démarré mais port 443 non détecté immédiatement"
fi
echo ""

# ─── ÉTAPE 6 : TESTS HTTPS ────────────────────────────────────────────────────
info "=== ÉTAPE 6 : Tests de connectivité HTTPS ==="
echo ""

curl_https_test() {
	local ns="$1" url="$2" label="$3"
	local result
	result=$(sudo ip netns exec "$ns" curl -sk --max-time 4 "$url" 2>/dev/null | grep -i '<h1>' | head -1)
	if [ -n "$result" ]; then
		ok "$label"
	else
		warn "$label — ÉCHEC"
	fi
}

echo -e "  ${JAUNE}--- Tests HTTPS locaux (depuis WEB) ---${RESET}"
curl_https_test WEB "https://127.0.0.1"    "HTTPS local WEB → localhost"
curl_https_test WEB "https://192.168.40.2" "HTTPS local WEB → 192.168.40.2"
echo ""

echo -e "  ${JAUNE}--- Tests HTTPS depuis PC1 ---${RESET}"
curl_https_test PC1 "https://192.168.40.2" "HTTPS PC1 → WEB par IP"
curl_https_test PC1 "https://web.lab.test" "HTTPS PC1 → WEB par DNS"
echo ""

echo -e "  ${JAUNE}--- Tests HTTPS depuis PC2 ---${RESET}"
curl_https_test PC2 "https://192.168.40.2" "HTTPS PC2 → WEB par IP"
curl_https_test PC2 "https://web.lab.test" "HTTPS PC2 → WEB par DNS"
echo ""

# Vérification de l'en-tête HSTS
info "Vérification de l'en-tête HSTS..."
HSTS=$(sudo ip netns exec WEB curl -skI --max-time 3 "https://127.0.0.1" 2>/dev/null \
	| grep -i "Strict-Transport-Security" | head -1)
if [ -n "$HSTS" ]; then
	ok "HSTS présent : $HSTS"
else
	warn "En-tête HSTS non détecté"
fi
echo ""

# Vérification du certificat
info "Informations sur le certificat SSL..."
sudo ip netns exec WEB bash -c \
	"echo | openssl s_client -connect 127.0.0.1:443 -servername ${DOMAIN} 2>/dev/null \
	| openssl x509 -noout -subject -dates 2>/dev/null" | sed 's/^/    /' || true
echo ""

# ─── RÉSUMÉ ───────────────────────────────────────────────────────────────────
echo -e "${VERT}============================================================${RESET}"
echo -e "${VERT}       HTTPS activé avec succès sur le serveur WEB !${RESET}"
echo -e "${VERT}============================================================${RESET}"
echo ""
echo "  Serveur Web HTTPS :"
echo "    URL     : https://web.lab.test"
echo "    IP      : https://192.168.40.2"
echo "    Cert    : auto-signé (CN=${DOMAIN}, RSA 2048, 365j)"
echo "    HSTS    : max-age=63072000 (includeSubDomains; preload)"
echo ""
echo "  Commandes de test :"
echo "    sudo ip netns exec PC1 curl -sk https://web.lab.test"
echo "    sudo ip netns exec PC2 curl -sk https://192.168.40.2"
echo "    sudo ip netns exec WEB curl -skI https://127.0.0.1 | grep Strict"
echo ""
echo "  Pour désactiver HTTPS : bash cleanup_https.sh"
echo "  Pour nettoyer tout    : bash cleanup_webserver.sh"
echo ""
