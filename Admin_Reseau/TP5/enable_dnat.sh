#!/bin/bash
# =============================================================================
# TP5 (Bonus) - Exposition externe du serveur HTTPS via DNAT
# Auteur : HATHOUTI Mohammed Taha
#
# Prérequis :
#   - enable_webserver.sh + enable_https.sh exécutés (Apache HTTPS sur port 443)
#
# Ce script :
#   1. Ajoute une règle DNAT sur le GATEWAY :
#      trafic entrant sur 209.165.200.226:443 → redirigé vers 192.168.40.2:443
#   2. Ajoute une règle FORWARD pour autoriser ce trafic
#   3. Teste l'accès HTTPS depuis l'ISP (simule un accès externe)
#
# En réseau réel : ISP = Internet, GATEWAY = routeur FAI, WEB = serveur interne
# =============================================================================

set -e

VERT="\e[32m"; ROUGE="\e[31m"; JAUNE="\e[33m"; BLEU="\e[34m"; RESET="\e[0m"
ok()   { echo -e "${VERT}[OK]${RESET}     $1"; }
info() { echo -e "${BLEU}[INFO]${RESET}   $1"; }
warn() { echo -e "${JAUNE}[WARN]${RESET}   $1"; }
fail() { echo -e "${ROUGE}[ERREUR]${RESET} $1"; exit 1; }

# IPs de référence (issues de setup_network.sh)
GW_WAN="209.165.200.226"    # IP publique du GATEWAY (interface veth3)
WEB_IP="192.168.40.2"       # IP privée du serveur WEB
HTTPS_PORT="443"

# ─── VÉRIFICATION DES PRÉREQUIS ──────────────────────────────────────────────
info "Vérification des prérequis (WEB + HTTPS + GATEWAY + ISP)..."

for ns in GATEWAY ISP WEB; do
	if ! sudo ip netns list | grep -q "^${ns}"; then
		fail "Namespace $ns manquant — lancez d'abord :\n  bash enable_webserver.sh && bash enable_https.sh"
	fi
done

if ! sudo ip netns exec WEB ss -tulnp 2>/dev/null | grep -q ':443'; then
	fail "Apache n'écoute pas sur le port 443 — lancez d'abord : bash enable_https.sh"
fi

ok "Prérequis satisfaits"
echo ""

# ─── ÉTAPE 1 : NETTOYAGE PRÉVENTIF ───────────────────────────────────────────
info "=== ÉTAPE 1 : Suppression des anciennes règles DNAT (si présentes) ==="

sudo ip netns exec GATEWAY iptables -t nat -D PREROUTING \
	-i veth3 -p tcp --dport ${HTTPS_PORT} \
	-j DNAT --to-destination ${WEB_IP}:${HTTPS_PORT} 2>/dev/null \
	&& warn "Ancienne règle DNAT supprimée" || true

sudo ip netns exec GATEWAY iptables -D FORWARD \
	-i veth3 -o veth-gw-web \
	-p tcp --dport ${HTTPS_PORT} \
	-d ${WEB_IP} -j ACCEPT 2>/dev/null \
	&& warn "Ancienne règle FORWARD supprimée" || true

ok "Nettoyage préventif terminé"
echo ""

# ─── ÉTAPE 2 : RÈGLE DNAT — PREROUTING ───────────────────────────────────────
info "=== ÉTAPE 2 : Règle DNAT (PREROUTING) sur le GATEWAY ==="

# Tout paquet TCP arrivant sur l'IP publique du GATEWAY sur le port 443
# est redirigé (DNAT) vers le serveur WEB privé
sudo ip netns exec GATEWAY iptables -t nat -A PREROUTING \
	-i veth3 \
	-p tcp --dport ${HTTPS_PORT} \
	-j DNAT --to-destination ${WEB_IP}:${HTTPS_PORT}

ok "DNAT : ${GW_WAN}:${HTTPS_PORT} → ${WEB_IP}:${HTTPS_PORT}"
echo ""

# ─── ÉTAPE 3 : RÈGLE FORWARD — AUTORISER LE TRAFIC DNATÉ ────────────────────
info "=== ÉTAPE 3 : Règle FORWARD pour le trafic entrant vers WEB ==="

sudo ip netns exec GATEWAY iptables -A FORWARD \
	-i veth3 -o veth-gw-web \
	-p tcp --dport ${HTTPS_PORT} \
	-d ${WEB_IP} -j ACCEPT

ok "FORWARD : veth3 → veth-gw-web (port ${HTTPS_PORT} vers ${WEB_IP})"

# Autoriser le trafic retour (connexions établies)
sudo ip netns exec GATEWAY iptables -A FORWARD \
	-i veth-gw-web -o veth3 \
	-m state --state ESTABLISHED,RELATED -j ACCEPT

ok "FORWARD retour : veth-gw-web → veth3 (ESTABLISHED,RELATED)"
echo ""

# ─── ÉTAPE 4 : VÉRIFICATION DES RÈGLES ───────────────────────────────────────
info "=== ÉTAPE 4 : Vérification des règles iptables ==="
echo ""
echo -e "  ${JAUNE}Règles NAT (PREROUTING) :${RESET}"
sudo ip netns exec GATEWAY iptables -t nat -L PREROUTING -v -n | sed 's/^/    /'
echo ""
echo -e "  ${JAUNE}Règles FORWARD :${RESET}"
sudo ip netns exec GATEWAY iptables -L FORWARD -v -n | sed 's/^/    /'
echo ""

# ─── ÉTAPE 5 : TEST DEPUIS L'ISP (simulation accès externe) ──────────────────
info "=== ÉTAPE 5 : Test HTTPS depuis l'ISP (accès externe simulé) ==="
echo ""

# L'ISP ping l'IP publique du GATEWAY
if sudo ip netns exec ISP ping -4 -c 2 -W 2 ${GW_WAN} &>/dev/null; then
	ok "Ping ISP → GATEWAY (${GW_WAN}) : OK"
else
	warn "Ping ISP → GATEWAY : ÉCHEC (normal si NAT asymétrique)"
fi

# L'ISP tente un accès HTTPS sur l'IP publique — doit atteindre le WEB interne
RESULT=$(sudo ip netns exec ISP curl -sk --max-time 4 "https://${GW_WAN}" 2>/dev/null | grep -i '<h1>' | head -1)
if [ -n "$RESULT" ]; then
	ok "HTTPS ISP → ${GW_WAN}:443 → WEB : OK (DNAT fonctionnel)"
else
	warn "HTTPS ISP → ${GW_WAN}:443 : ÉCHEC — vérifiez les routes et le FORWARD"
fi
echo ""

# ─── RÉSUMÉ ───────────────────────────────────────────────────────────────────
echo -e "${VERT}============================================================${RESET}"
echo -e "${VERT}   Exposition externe HTTPS via DNAT configurée ! (Bonus)${RESET}"
echo -e "${VERT}============================================================${RESET}"
echo ""
echo "  Flux DNAT :"
echo "    ISP → ${GW_WAN}:443"
echo "    GATEWAY (DNAT) → ${WEB_IP}:443"
echo "    Réponse : ${WEB_IP}:443 → GATEWAY → ISP"
echo ""
echo "  En environnement réel :"
echo "    Internet → IP publique routeur:443 → serveur interne:443"
echo ""
echo "  Commande de test :"
echo "    sudo ip netns exec ISP curl -sk https://${GW_WAN}"
echo ""
echo "  Pour nettoyer le DNAT : relancer cleanup_webserver.sh"
echo ""
