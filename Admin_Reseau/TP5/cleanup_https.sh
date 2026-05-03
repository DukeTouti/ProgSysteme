#!/bin/bash
# =============================================================================
# TP5 - Nettoyage HTTPS — retour en mode HTTP uniquement
# Préserve : namespace WEB, Apache, TP0, TP3, TP4
# Auteur : HATHOUTI Mohammed Taha
# =============================================================================

VERT="\e[32m"; ROUGE="\e[31m"; JAUNE="\e[33m"; BLEU="\e[34m"; RESET="\e[0m"
info() { echo -e "${BLEU}[INFO]${RESET}   $1"; }
ok()   { echo -e "${VERT}[OK]${RESET}     $1"; }
warn() { echo -e "${JAUNE}[SKIP]${RESET}   $1 (inexistant)"; }

echo ""
info "=== NETTOYAGE HTTPS — TP5 (retour HTTP, namespace WEB préservé) ==="
echo ""

# ─── VÉRIFICATION ────────────────────────────────────────────────────────────
if ! sudo ip netns list 2>/dev/null | grep -q "^WEB"; then
	echo -e "${ROUGE}[ERREUR]${RESET} Namespace WEB introuvable — rien à nettoyer."
	exit 0
fi

# ─── ARRÊT D'APACHE ───────────────────────────────────────────────────────────
info "Arrêt d'Apache dans le namespace WEB..."
sudo ip netns exec WEB pkill apache2 2>/dev/null && ok "apache2 arrêté" || warn "apache2"
sleep 1

# ─── DÉSACTIVATION DU SITE SSL ────────────────────────────────────────────────
info "Désactivation du site HTTPS (web-ssl.conf)..."
sudo a2dissite web-ssl.conf 2>/dev/null && ok "Site web-ssl.conf désactivé" || warn "web-ssl.conf"

# ─── DÉSACTIVATION DES MODULES SSL ───────────────────────────────────────────
info "Désactivation du module ssl..."
sudo a2dismod ssl 2>/dev/null && ok "Module ssl désactivé" || warn "ssl"

# ─── SUPPRESSION DES FICHIERS SSL ─────────────────────────────────────────────
info "Suppression des fichiers SSL..."
for f in \
	/etc/apache2/ssl/web.lab.test.key \
	/etc/apache2/ssl/web.lab.test.crt \
	/etc/apache2/sites-available/web-ssl.conf
do
	if [ -f "$f" ]; then
		sudo rm -f "$f" && ok "Supprimé : $f"
	else
		warn "$f"
	fi
done

# Supprimer le répertoire ssl s'il est vide
sudo rmdir /etc/apache2/ssl 2>/dev/null && ok "/etc/apache2/ssl/ supprimé (vide)" || true

# ─── RESTAURATION DU SITE HTTP PAR DÉFAUT ────────────────────────────────────
info "Réactivation du site HTTP par défaut (000-default.conf)..."
sudo a2ensite 000-default.conf 2>/dev/null && ok "Site 000-default.conf réactivé" || warn "000-default.conf"

# ─── RESTAURATION DE LA PAGE WEB (HTTP) ──────────────────────────────────────
info "Restauration de la page web (mention HTTP)..."
sudo bash -c 'cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html lang="fr">
<head><meta charset="UTF-8"><title>TP5 Web Server HTTP — UIR</title></head>
<body>
  <h1>Serveur Web opérationnel (HTTP)</h1>
  <p>Namespace : WEB | IP : 192.168.40.2 | Domaine : web.lab.test</p>
  <p>HTTPS désactivé — mode HTTP uniquement</p>
  <p>Auteur : HATHOUTI Mohammed Taha — UIR/ESIN 3A Cybersécurité</p>
</body>
</html>
EOF'
ok "Page /var/www/html/index.html restaurée (HTTP)"

# ─── REDÉMARRAGE APACHE EN MODE HTTP ─────────────────────────────────────────
info "Redémarrage d'Apache (HTTP uniquement) dans le namespace WEB..."

sudo ip netns exec WEB mkdir -p /run/apache2 /var/log/apache2
sudo ip netns exec WEB chown www-data:www-data /run/apache2 /var/log/apache2 2>/dev/null || true

sudo ip netns exec WEB bash -c 'source /etc/apache2/envvars && /usr/sbin/apache2 -k start 2>/dev/null'
sleep 2

if sudo ip netns exec WEB ss -tulnp | grep -q ':80'; then
	ok "Apache redémarré — écoute sur le port 80 (HTTP)"
else
	warn "Apache redémarré mais port 80 non détecté immédiatement"
fi
echo ""

# ─── VÉRIFICATION HTTP ────────────────────────────────────────────────────────
info "=== Vérification que HTTP fonctionne toujours ==="
echo ""

curl_test() {
	local ns="$1" url="$2" label="$3"
	local result
	result=$(sudo ip netns exec "$ns" curl -s --max-time 3 "$url" 2>/dev/null | head -1)
	if [ -n "$result" ]; then
		ok "$label"
	else
		warn "$label — ÉCHEC"
	fi
}

curl_test WEB "http://127.0.0.1"    "HTTP local (WEB → localhost)"
curl_test PC1 "http://192.168.40.2" "HTTP depuis PC1 par IP"
curl_test PC1 "http://web.lab.test" "HTTP depuis PC1 par DNS"

echo ""
echo -e "${VERT}=================================================================${RESET}"
echo -e "${VERT}  HTTPS désactivé. Serveur WEB opérationnel en HTTP uniquement.${RESET}"
echo -e "${VERT}=================================================================${RESET}"
echo ""
echo -e "  ${VERT}Pour réactiver HTTPS  :${RESET} ${JAUNE}bash enable_https.sh${RESET}"
echo -e "  ${VERT}Pour tout nettoyer    :${RESET} ${JAUNE}bash cleanup_webserver.sh${RESET}"
echo ""
