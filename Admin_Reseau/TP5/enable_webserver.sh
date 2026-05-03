#!/bin/bash
# =============================================================================
# TP5 - Déploiement du serveur Web interne (Apache HTTP)
# Auteur : HATHOUTI Mohammed Taha
#
# Prérequis :
#   - setup_network.sh  (TP0) exécuté
#   - enable_static_nat.sh (TP3) exécuté
#   - enable_dns.sh     (TP4) exécuté
#
# Ce script :
#   1. Crée le namespace WEB (192.168.40.2/24)
#   2. Le connecte au GATEWAY
#   3. Configure le routage + NAT pour WEB
#   4. Met à jour la zone DNS : lab.local → lab.test + enregistrement web
#   5. Installe et démarre Apache (HTTP port 80)
#   6. Teste la connectivité depuis PC1 et PC2
# =============================================================================

set -e

VERT="\e[32m"; ROUGE="\e[31m"; JAUNE="\e[33m"; BLEU="\e[34m"; RESET="\e[0m"
ok()   { echo -e "${VERT}[OK]${RESET}     $1"; }
info() { echo -e "${BLEU}[INFO]${RESET}   $1"; }
warn() { echo -e "${JAUNE}[WARN]${RESET}   $1"; }
fail() { echo -e "${ROUGE}[ERREUR]${RESET} $1"; exit 1; }

DOMAIN="web.lab.test"

# ─── VÉRIFICATION DES PRÉREQUIS ──────────────────────────────────────────────
info "Vérification des prérequis (TP0 + TP3 + TP4)..."

for ns in PC1 PC2 GATEWAY ISP DNS; do
	if ! sudo ip netns list | grep -q "^${ns}"; then
		fail "Namespace $ns manquant — lancez les scripts précédents :\n  bash setup_network.sh && bash enable_static_nat.sh && bash enable_dns.sh"
	fi
done

# Vérifier que BIND tourne dans DNS
if ! sudo ip netns exec DNS pgrep named >/dev/null 2>&1; then
	fail "named ne tourne pas dans le namespace DNS — relancez : bash enable_dns.sh"
fi

ok "Tous les prérequis sont satisfaits (TP0 + TP3 + TP4)"
echo ""

# ─── ÉTAPE 1 : NETTOYAGE PRÉVENTIF WEB ───────────────────────────────────────
info "=== ÉTAPE 1 : Nettoyage préventif WEB ==="

sudo ip netns exec WEB pkill apache2 2>/dev/null && warn "apache2 arrêté" || true
sudo ip link del veth-gw-web 2>/dev/null && warn "Interface veth-gw-web supprimée" || true
sudo ip netns exec GATEWAY ip link del veth-gw-web 2>/dev/null || true
sudo ip netns del WEB 2>/dev/null && warn "Namespace WEB supprimé" || true

ok "Nettoyage préventif terminé"
echo ""

# ─── ÉTAPE 2 : CRÉATION DU NAMESPACE WEB ─────────────────────────────────────
info "=== ÉTAPE 2 : Création du namespace WEB ==="

sudo ip netns add WEB
sudo ip netns exec WEB ip link set lo up
ok "Namespace WEB créé (loopback UP)"
echo ""

# ─── ÉTAPE 3 : PAIRE VETH WEB ↔ GATEWAY ─────────────────────────────────────
info "=== ÉTAPE 3 : Création du lien virtuel WEB ↔ GATEWAY ==="

sudo ip link add veth-gw-web type veth peer name veth-web
ok "veth-gw-web <-> veth-web (GATEWAY ↔ WEB)"

sudo ip link set veth-web   netns WEB
sudo ip link set veth-gw-web netns GATEWAY
ok "veth-web     → namespace WEB"
ok "veth-gw-web  → namespace GATEWAY"
echo ""

# ─── ÉTAPE 4 : ADRESSAGE IP ───────────────────────────────────────────────────
info "=== ÉTAPE 4 : Configuration IP ==="

# Côté WEB
sudo ip netns exec WEB ip addr add 192.168.40.2/24 dev veth-web
sudo ip netns exec WEB ip link set veth-web up
ok "WEB     : veth-web = 192.168.40.2/24 ${VERT}[UP]${RESET}"

# Côté GATEWAY
sudo ip netns exec GATEWAY ip addr add 192.168.40.1/24 dev veth-gw-web
sudo ip netns exec GATEWAY ip link set veth-gw-web up
ok "GATEWAY : veth-gw-web = 192.168.40.1/24 ${VERT}[UP]${RESET}"
echo ""

# ─── ÉTAPE 5 : ROUTAGE ───────────────────────────────────────────────────────
info "=== ÉTAPE 5 : Configuration du routage ==="

# Route par défaut WEB → GATEWAY
sudo ip netns exec WEB ip route add default via 192.168.40.1
ok "WEB : route par défaut via 192.168.40.1 (GATEWAY)"

# Routes retour vers WEB depuis PC1 et PC2
sudo ip netns exec PC1 ip route replace 192.168.40.0/24 via 192.168.10.1
ok "PC1 : route 192.168.40.0/24 via 192.168.10.1"

sudo ip netns exec PC2 ip route replace 192.168.40.0/24 via 192.168.20.1
ok "PC2 : route 192.168.40.0/24 via 192.168.20.1"

# Route retour WEB sur ISP (pour que l'ISP sache renvoyer les paquets)
sudo ip netns exec ISP ip route replace 192.168.40.0/24 via 209.165.200.226
ok "ISP : route 192.168.40.0/24 via 209.165.200.226 (GATEWAY WAN)"
echo ""

# ─── ÉTAPE 6 : NAT POUR LE NAMESPACE WEB ─────────────────────────────────────
info "=== ÉTAPE 6 : Règle MASQUERADE pour le trafic sortant de WEB ==="

# veth3 = interface WAN du GATEWAY (définie dans setup_network.sh / TP0)
sudo ip netns exec GATEWAY iptables -t nat -A POSTROUTING \
	-s 192.168.40.0/24 -o veth3 -j MASQUERADE
ok "MASQUERADE : 192.168.40.0/24 → veth3 (WAN)"
echo ""

# ─── ÉTAPE 7 : RÉSOLVEUR DNS DANS WEB ────────────────────────────────────────
info "=== ÉTAPE 7 : Configuration du résolveur DNS dans WEB ==="

sudo ip netns exec WEB bash -c 'echo "nameserver 192.168.30.2" >  /etc/resolv.conf'
sudo ip netns exec WEB bash -c 'echo "nameserver 8.8.8.8"      >> /etc/resolv.conf'
ok "WEB : resolv.conf → 192.168.30.2 (DNS lab) | 8.8.8.8 (fallback)"

# Route vers le réseau DNS
sudo ip netns exec WEB ip route replace 192.168.30.0/24 via 192.168.40.1
ok "WEB : route 192.168.30.0/24 via 192.168.40.1"
echo ""

# ─── ÉTAPE 8 : MISE À JOUR DU DNS — lab.local → lab.test + enreg. web ────────
info "=== ÉTAPE 8 : Mise à jour de la zone DNS (lab.local → lab.test + web) ==="

# Arrêt de named
sudo ip netns exec DNS pkill named 2>/dev/null && warn "named arrêté" || true
sleep 1

# Nouvelle zone directe lab.test (remplace lab.local)
sudo tee /etc/bind/db.lab.test >/dev/null <<EOF
; Zone directe — lab.test
; Auteur : HATHOUTI Mohammed Taha
\$TTL 604800
@	IN	SOA	ns.lab.test. admin.lab.test. (
			20260102	; Serial
			604800		; Refresh
			86400		; Retry
			2419200		; Expire
			604800 )	; Minimum TTL

@	IN	NS	ns.lab.test.

ns	IN	A	192.168.30.2
pc1	IN	A	192.168.10.10
pc2	IN	A	192.168.20.10
web	IN	A	192.168.40.2
EOF
ok "Zone directe créée : /etc/bind/db.lab.test"

# Mise à jour de named.conf.local : suppression lab.local, ajout lab.test
sudo tee /etc/bind/named.conf.local >/dev/null <<EOF
// Configuration des zones autoritaires — TP5 Web Server
// Auteur : HATHOUTI Mohammed Taha

zone "lab.test" {
	type master;
	file "/etc/bind/db.lab.test";
};

zone "30.168.192.in-addr.arpa" {
	type master;
	file "/etc/bind/db.192.168.30";
};
EOF
ok "named.conf.local mis à jour (lab.local → lab.test)"

# Validation de la zone
sudo ip netns exec DNS named-checkconf 2>/dev/null \
	&& ok "named-checkconf : configuration valide" \
	|| warn "Avertissements dans named-checkconf"

sudo ip netns exec DNS named-checkzone lab.test /etc/bind/db.lab.test 2>/dev/null \
	&& ok "named-checkzone lab.test : zone valide" \
	|| warn "Avertissements sur la zone lab.test"

# Redémarrage de named
sudo ip netns exec DNS named -c /etc/bind/named.conf &
sleep 2

if sudo ip netns exec DNS pgrep named >/dev/null 2>&1; then
	ok "named redémarré avec la zone lab.test"
else
	fail "named n'a pas redémarré — vérifiez la configuration BIND"
fi

# Mise à jour resolv.conf sur PC1, PC2
for ns in PC1 PC2; do
	sudo ip netns exec $ns bash -c 'echo "nameserver 192.168.30.2" >  /etc/resolv.conf'
	sudo ip netns exec $ns bash -c 'echo "nameserver 8.8.8.8"      >> /etc/resolv.conf'
done
ok "PC1 et PC2 : resolv.conf mis à jour"
echo ""

# ─── ÉTAPE 9 : INSTALLATION D'APACHE ─────────────────────────────────────────
info "=== ÉTAPE 9 : Vérification / Installation d'Apache dans WEB ==="

# Apache est installé sur l'hôte et partagé par les namespaces (même filesystem)
if ! which apache2 >/dev/null 2>&1; then
	warn "apache2 non trouvé — installation en cours..."
	sudo apt-get update -qq && sudo apt-get install -y -qq apache2
fi

APACHE_VER=$(apache2 -v 2>&1 | head -1)
ok "Apache disponible : $APACHE_VER"
echo ""

# ─── ÉTAPE 10 : CRÉATION DE LA PAGE WEB ──────────────────────────────────────
info "=== ÉTAPE 10 : Création de la page web de test ==="

sudo bash -c 'cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html lang="fr">
<head><meta charset="UTF-8"><title>TP5 Web Server — UIR</title></head>
<body>
  <h1>Serveur Web opérationnel (HTTP)</h1>
  <p>Namespace : WEB | IP : 192.168.40.2 | Domaine : web.lab.test</p>
  <p>Auteur : HATHOUTI Mohammed Taha — UIR/ESIN 3A Cybersécurité</p>
</body>
</html>
EOF'
ok "Page /var/www/html/index.html créée"
echo ""

# ─── ÉTAPE 11 : DÉMARRAGE D'APACHE (HTTP) ────────────────────────────────────
info "=== ÉTAPE 11 : Démarrage d'Apache dans le namespace WEB (port 80) ==="

sudo ip netns exec WEB pkill apache2 2>/dev/null || true
sleep 1

sudo ip netns exec WEB mkdir -p /run/apache2 /var/log/apache2
sudo ip netns exec WEB chown www-data:www-data /run/apache2 /var/log/apache2 2>/dev/null || true

# Désactiver le SSL si activé, activer le site par défaut HTTP
sudo a2dismod ssl   >/dev/null 2>&1 || true
sudo a2dissite web-ssl.conf >/dev/null 2>&1 || true
sudo a2ensite 000-default.conf >/dev/null 2>&1 || true

sudo ip netns exec WEB bash -c 'source /etc/apache2/envvars && /usr/sbin/apache2 -k start 2>/dev/null'
sleep 2

if sudo ip netns exec WEB ss -tulnp | grep -q ':80'; then
	ok "Apache démarré — écoute sur le port 80"
else
	warn "Apache démarré mais port 80 non détecté immédiatement"
fi
echo ""

# ─── ÉTAPE 12 : TESTS DE CONNECTIVITÉ ET SERVICE ─────────────────────────────
info "=== ÉTAPE 12 : Tests de connectivité et service ==="
echo ""

ping_test() {
	local ns="$1" dest="$2" label="$3"
	if sudo ip netns exec "$ns" ping -4 -c 2 -W 2 "$dest" &>/dev/null; then
		ok "$label"
	else
		warn "$label — ÉCHEC"
	fi
}

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

dns_test() {
	local ns="$1" hostname="$2" expected_ip="$3"
	local resolved
	resolved=$(sudo ip netns exec "$ns" dig +short "$hostname" @192.168.30.2 2>/dev/null | head -1)
	if [ "$resolved" = "$expected_ip" ]; then
		ok "DNS $ns : $hostname → $resolved"
	else
		warn "DNS $ns : $hostname → ${resolved:-(aucune réponse)} (attendu $expected_ip)"
	fi
}

echo -e "  ${JAUNE}--- Tests ping ---${RESET}"
ping_test WEB 192.168.40.1  "WEB → GATEWAY (192.168.40.1)"
ping_test WEB 192.168.10.10 "WEB → PC1 (192.168.10.10)"
ping_test WEB 192.168.20.10 "WEB → PC2 (192.168.20.10)"
ping_test PC1 192.168.40.2  "PC1 → WEB (192.168.40.2)"
ping_test PC2 192.168.40.2  "PC2 → WEB (192.168.40.2)"
echo ""

echo -e "  ${JAUNE}--- Tests DNS ---${RESET}"
dns_test PC1 "web.lab.test" "192.168.40.2"
dns_test PC2 "web.lab.test" "192.168.40.2"
dns_test PC1 "pc2.lab.test" "192.168.20.10"
echo ""

echo -e "  ${JAUNE}--- Tests HTTP ---${RESET}"
curl_test WEB  "http://127.0.0.1"      "HTTP local (WEB → localhost)"
curl_test PC1  "http://192.168.40.2"   "HTTP depuis PC1 par IP"
curl_test PC2  "http://192.168.40.2"   "HTTP depuis PC2 par IP"
curl_test PC1  "http://web.lab.test"   "HTTP depuis PC1 par DNS"
curl_test PC2  "http://web.lab.test"   "HTTP depuis PC2 par DNS"
echo ""

# ─── RÉSUMÉ ───────────────────────────────────────────────────────────────────
echo -e "${VERT}============================================================${RESET}"
echo -e "${VERT}       Serveur Web TP5 déployé avec succès !${RESET}"
echo -e "${VERT}============================================================${RESET}"
echo ""
echo "  Topologie TP5 :"
echo "    PC1     : 192.168.10.10   (LAN1)"
echo "    PC2     : 192.168.20.10   (LAN2)"
echo "    DNS     : 192.168.30.2    (réseau DNS)"
echo "    WEB     : 192.168.40.2    (réseau WEB)"
echo "    GATEWAY : 192.168.10.1 | .20.1 | .30.1 | .40.1 | 209.165.200.226"
echo "    ISP     : 209.165.200.225"
echo ""
echo "  Zone DNS : lab.test"
echo "    web.lab.test  → 192.168.40.2"
echo "    pc1.lab.test  → 192.168.10.10"
echo "    pc2.lab.test  → 192.168.20.10"
echo "    ns.lab.test   → 192.168.30.2"
echo ""
echo "  Commandes de test :"
echo "    sudo ip netns exec PC1 curl http://web.lab.test"
echo "    sudo ip netns exec PC2 curl http://192.168.40.2"
echo "    sudo ip netns exec PC1 dig web.lab.test @192.168.30.2 +short"
echo ""
echo "  Pour activer HTTPS : bash enable_https.sh"
echo "  Pour nettoyer      : bash cleanup_webserver.sh"
echo ""
