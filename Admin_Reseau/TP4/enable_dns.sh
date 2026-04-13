#!/bin/bash
# =============================================================================
# TP4 - Installation et Configuration d'un serveur DNS (BIND)
# Script de déploiement du namespace DNS et configuration BIND9
# Auteur : HATHOUTI Mohammed Taha
# =============================================================================

set -e

VERT="\e[32m"; ROUGE="\e[31m"; JAUNE="\e[33m"; BLEU="\e[34m"; RESET="\e[0m"
ok()   { echo -e "${VERT}[OK]${RESET}     $1"; }
info() { echo -e "${BLEU}[INFO]${RESET}   $1"; }
warn() { echo -e "${JAUNE}[WARN]${RESET}   $1"; }
fail() { echo -e "${ROUGE}[ERREUR]${RESET} $1"; exit 1; }

# ─── VÉRIFICATION DU RÉSEAU DE BASE (TP0) ────────────────────────────────────
info "Vérification que le réseau TP0 est bien déployé..."
for ns in PC1 PC2 GATEWAY ISP; do
	if ! sudo ip netns list | grep -q "^${ns}"; then
		fail "Namespace $ns manquant — lancez d'abord : bash setup_network.sh"
	fi
done
ok "Réseau TP0 détecté"
echo ""

# ─── ÉTAPE 1 : NETTOYAGE PRÉVENTIF DNS ───────────────────────────────────────
info "=== ÉTAPE 1 : Nettoyage préventif DNS ==="

# Arrêt de tout processus named en cours dans le namespace DNS
sudo ip netns exec DNS pkill named 2>/dev/null && warn "named arrêté" || true

# Suppression des interfaces veth résiduelles
sudo ip link del veth-dns 2>/dev/null && warn "Interface veth-dns supprimée" || true
sudo ip link del gw-dns   2>/dev/null && warn "Interface gw-dns supprimée"   || true

# Suppression de l'ancien namespace DNS
sudo ip netns del DNS 2>/dev/null && warn "Namespace DNS supprimé" || true

ok "Nettoyage DNS terminé"
echo ""

# ─── ÉTAPE 2 : CRÉATION DU NAMESPACE DNS ─────────────────────────────────────
info "=== ÉTAPE 2 : Création du namespace DNS ==="

sudo ip netns add DNS
sudo ip netns exec DNS ip link set lo up
ok "Namespace DNS créé (loopback UP)"
echo ""

# ─── ÉTAPE 3 : CRÉATION DE LA PAIRE VETH DNS ↔ GATEWAY ───────────────────────
info "=== ÉTAPE 3 : Création du lien virtuel DNS ↔ GATEWAY ==="

sudo ip link add veth-dns type veth peer name gw-dns
ok "veth-dns <-> gw-dns (DNS ↔ GATEWAY)"

sudo ip link set veth-dns netns DNS
sudo ip link set gw-dns   netns GATEWAY
ok "veth-dns → namespace DNS"
ok "gw-dns   → namespace GATEWAY"
echo ""

# ─── ÉTAPE 4 : ADRESSAGE IP — CÔTÉ DNS ───────────────────────────────────────
info "=== ÉTAPE 4 : Configuration IP — côté DNS ==="

sudo ip netns exec DNS ip addr add 192.168.30.2/24 dev veth-dns
sudo ip netns exec DNS ip link set veth-dns up
sudo ip netns exec DNS ip route add default via 192.168.30.1
ok "DNS     : veth-dns = 192.168.30.2/24 ${VERT}[UP]${RESET}"
ok "DNS     : route par défaut via 192.168.30.1 (GATEWAY)"
echo ""

# ─── ÉTAPE 5 : ADRESSAGE IP — CÔTÉ GATEWAY ───────────────────────────────────
info "=== ÉTAPE 5 : Configuration IP — côté GATEWAY ==="

sudo ip netns exec GATEWAY ip addr add 192.168.30.1/24 dev gw-dns
sudo ip netns exec GATEWAY ip link set gw-dns up
sudo ip netns exec GATEWAY sysctl -w net.ipv4.ip_forward=1 2>/dev/null || true
sudo ip netns exec GATEWAY bash -c 'echo 1 > /proc/sys/net/ipv4/ip_forward' 2>/dev/null || true
ok "GATEWAY : gw-dns = 192.168.30.1/24 ${VERT}[UP]${RESET}"
ok "GATEWAY : IP forwarding activé"
echo ""

# ─── ÉTAPE 5b : PONT DIRECT NAMESPACE DNS ↔ HÔTE ────────────────────────────
info "=== ÉTAPE 5b : Connexion directe namespace DNS ↔ hôte (accès Internet réel) ==="

# ISP est un namespace simulé sans Internet — le MASQUERADE via veth3 ne suffit pas.
# Solution : créer une veth entre le namespace DNS et le réseau hôte (netns racine),
# puis forwarder via l'IP réelle de l'hôte (192.168.11.105) vers Internet.

# Nettoyage préventif
sudo ip link del veth-host-dns 2>/dev/null || true

# Créer la paire veth : veth-host-dns (hôte) <-> veth-dns-host (namespace DNS)
sudo ip link add veth-host-dns type veth peer name veth-dns-host
ok "veth-host-dns <-> veth-dns-host créées"

# Mettre veth-dns-host dans le namespace DNS (veth-host-dns reste dans l'hôte)
sudo ip link set veth-dns-host netns DNS
ok "veth-dns-host → namespace DNS"

# Configurer côté hôte
sudo ip addr add 10.200.0.1/30 dev veth-host-dns 2>/dev/null || true
sudo ip link set veth-host-dns up
ok "Hôte : veth-host-dns = 10.200.0.1/30 [UP]"

# Configurer côté namespace DNS
sudo ip netns exec DNS ip addr add 10.200.0.2/30 dev veth-dns-host
sudo ip netns exec DNS ip link set veth-dns-host up
ok "DNS  : veth-dns-host = 10.200.0.2/30 [UP]"

# Remplacer la route par défaut du namespace DNS par la veth hôte
# (l'hôte fait du forwarding IP et a un accès Internet réel)
sudo ip netns exec DNS ip route replace default via 10.200.0.1
ok "DNS  : route par défaut → 10.200.0.1 (hôte)"

# Routes spécifiques pour que les réponses DNS reviennent bien vers les LANs
# via le GATEWAY (et non par la veth hôte qui est la route par défaut)
sudo ip netns exec DNS ip route add 192.168.10.0/24 via 192.168.30.1
ok "DNS  : route 192.168.10.0/24 via 192.168.30.1 (LAN1 → GATEWAY)"
sudo ip netns exec DNS ip route add 192.168.20.0/24 via 192.168.30.1
ok "DNS  : route 192.168.20.0/24 via 192.168.30.1 (LAN2 → GATEWAY)"

# Activer le forwarding IP sur l'hôte pour que les paquets du namespace DNS sortent
sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
# MASQUERADE sur l'hôte : paquets venant du namespace DNS sortent avec l'IP réelle
IFACE_SORTIE=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'dev \K\S+' | head -1)
sudo iptables -t nat -A POSTROUTING -s 10.200.0.2/32 -o "$IFACE_SORTIE" -j MASQUERADE 2>/dev/null || true
ok "MASQUERADE hôte : 10.200.0.2 -> $IFACE_SORTIE (Internet)"
echo ""

# ─── ÉTAPE 6 : INSTALLATION DE BIND9 ─────────────────────────────────────────
info "=== ÉTAPE 6 : Vérification / Installation de BIND9 ==="

sudo ip netns exec DNS bash -c \
	"command -v named >/dev/null 2>&1 || (apt-get update -qq && apt-get install -y -qq bind9 bind9utils)"
NAMED_VER=$(sudo ip netns exec DNS named -v 2>&1 | head -1)
ok "BIND9 disponible : $NAMED_VER"
echo ""

# ─── ÉTAPE 7 : CRÉATION DES FICHIERS DE ZONE BIND ────────────────────────────
info "=== ÉTAPE 7 : Création des fichiers de zone BIND ==="

# Zone directe : lab.local (hostname → IP)
sudo tee /etc/bind/db.lab.local >/dev/null <<EOF
; Zone directe — lab.local
; Auteur : HATHOUTI Mohammed Taha
\$TTL 604800
@	IN	SOA	ns.lab.local. admin.lab.local. (
			20260101	; Serial   (YYYYMMDD)
			604800		; Refresh  (7 jours)
			86400		; Retry    (1 jour)
			2419200		; Expire   (28 jours)
			604800 )	; Minimum TTL (7 jours)

; Serveur de noms autoritaire pour lab.local
@	IN	NS	ns.lab.local.

; Enregistrements A (hostname → IP)
ns	IN	A	192.168.30.2	; ns.lab.local  → 192.168.30.2
PC1	IN	A	192.168.10.10	; PC1.lab.local → 192.168.10.10
PC2	IN	A	192.168.20.10	; PC2.lab.local → 192.168.20.10
EOF
ok "Zone directe créée  : /etc/bind/db.lab.local"

# Zone inverse : 192.168.30.0/24 (IP → hostname)
sudo tee /etc/bind/db.192.168.30 >/dev/null <<EOF
; Zone inverse — 192.168.30.0/24
; Auteur : HATHOUTI Mohammed Taha
\$TTL 604800
@	IN	SOA	ns.lab.local. admin.lab.local. (
			20260101	; Serial
			604800		; Refresh
			86400		; Retry
			2419200		; Expire
			604800 )	; Minimum TTL

; Serveur de noms responsable des lookups inverses
@	IN	NS	ns.lab.local.

; Enregistrement PTR : 192.168.30.2 → ns.lab.local
; "2" est le dernier octet de 192.168.30.2
; Utilisé pour la résolution inverse (IP → nom)
2	IN	PTR	ns.lab.local.
EOF
ok "Zone inverse créée  : /etc/bind/db.192.168.30"
echo ""

# ─── ÉTAPE 8 : DÉCLARATION DES ZONES DANS named.conf.local ───────────────────
info "=== ÉTAPE 8 : Déclaration des zones dans named.conf.local ==="

sudo tee /etc/bind/named.conf.local >/dev/null <<EOF
// Configuration des zones autoritaires — TP4 DNS
// Auteur : HATHOUTI Mohammed Taha

// Zone directe : résolution hostname → IP
zone "lab.local" {
	type master;
	file "/etc/bind/db.lab.local";
};

// Zone inverse : résolution IP → hostname pour 192.168.30.0/24
zone "30.168.192.in-addr.arpa" {
	type master;
	file "/etc/bind/db.192.168.30";
};
EOF
ok "named.conf.local configuré"
echo ""

# ─── ÉTAPE 9 : CONFIGURATION DES OPTIONS BIND (forwarding externe) ───────────
info "=== ÉTAPE 9 : Configuration des options BIND (recursion + forwarding) ==="

sudo tee /etc/bind/named.conf.options >/dev/null <<EOF
// Options BIND9 — TP4 DNS
// Auteur : HATHOUTI Mohammed Taha

options {
	directory "/var/cache/bind";

	// Activation de la récursivité : BIND peut interroger des DNS externes
	recursion yes;

	// Accepter les requêtes depuis n'importe quelle IP (lab uniquement)
	allow-query { any; };

	// Écouter uniquement sur l'interface du namespace DNS
	listen-on { 192.168.30.2; };

	// Forcer BIND à utiliser 10.200.0.2 comme IP source pour les requêtes
	// sortantes vers les forwarders — sinon BIND utilise 192.168.30.2 (privée)
	// et 8.8.8.8 ne peut pas répondre à cette IP non routable sur Internet
	query-source address 10.200.0.2;

	// Forwarders : 8.8.8.8 est atteignable directement depuis le namespace DNS
	// via la veth hôte (10.200.0.1) avec MASQUERADE
	forwarders {
		8.8.8.8;
		8.8.4.4;
	};

	dnssec-validation no;
};
EOF
ok "named.conf.options configuré (forwarding vers 8.8.8.8 via veth hôte)"
echo ""

# ─── ÉTAPE 10 : VALIDATION DE LA CONFIGURATION BIND ─────────────────────────
info "=== ÉTAPE 10 : Validation de la configuration BIND ==="

sudo ip netns exec DNS named-checkconf 2>/dev/null && ok "named-checkconf : configuration valide" \
	|| warn "named-checkconf a retourné des avertissements — vérifiez manuellement"

sudo ip netns exec DNS named-checkzone lab.local /etc/bind/db.lab.local 2>/dev/null \
	&& ok "named-checkzone lab.local : zone valide" \
	|| warn "Avertissement sur la zone lab.local"
echo ""

# ─── ÉTAPE 11 : DÉMARRAGE DU SERVEUR DNS ─────────────────────────────────────
info "=== ÉTAPE 11 : Démarrage du serveur DNS (named) ==="

# Arrêt de tout processus named résiduel
sudo ip netns exec DNS pkill named 2>/dev/null || true
sleep 1

# Démarrage de named dans le namespace DNS
sudo ip netns exec DNS named -c /etc/bind/named.conf &
sleep 2

# Vérification que named tourne
if sudo ip netns exec DNS pgrep named >/dev/null 2>&1; then
	ok "named en cours d'exécution dans le namespace DNS"
else
	fail "named ne s'est pas lancé — vérifiez la configuration BIND"
fi
echo ""

# ─── ÉTAPE 12 : CONFIGURATION DNS SUR LES CLIENTS ────────────────────────────
info "=== ÉTAPE 12 : Configuration des résolveurs DNS sur PC1 et PC2 ==="

# PC1 : résolveur primaire = DNS lab, fallback = Google DNS
sudo ip netns exec PC1 bash -c 'echo "nameserver 192.168.30.2" >  /etc/resolv.conf'
sudo ip netns exec PC1 bash -c 'echo "nameserver 8.8.8.8"      >> /etc/resolv.conf'
ok "PC1 : resolv.conf → 192.168.30.2 (primaire) | 8.8.8.8 (fallback)"

# PC2 : idem
sudo ip netns exec PC2 bash -c 'echo "nameserver 192.168.30.2" >  /etc/resolv.conf'
sudo ip netns exec PC2 bash -c 'echo "nameserver 8.8.8.8"      >> /etc/resolv.conf'
ok "PC2 : resolv.conf → 192.168.30.2 (primaire) | 8.8.8.8 (fallback)"
echo ""

# ─── ÉTAPE 13 : AJOUT DES ROUTES VERS LE RÉSEAU DNS ─────────────────────────
info "=== ÉTAPE 13 : Ajout des routes vers le réseau DNS (192.168.30.0/24) ==="

# PC1 : pour atteindre 192.168.30.0/24, passer par sa passerelle 192.168.10.1
sudo ip netns exec PC1 ip route replace 192.168.30.0/24 via 192.168.10.1
ok "PC1 : route 192.168.30.0/24 via 192.168.10.1"

# PC2 : pour atteindre 192.168.30.0/24, passer par sa passerelle 192.168.20.1
sudo ip netns exec PC2 ip route replace 192.168.30.0/24 via 192.168.20.1
ok "PC2 : route 192.168.30.0/24 via 192.168.20.1"
echo ""

# ─── RÉSUMÉ ───────────────────────────────────────────────────────────────────
echo -e "${VERT}============================================================${RESET}"
echo -e "${VERT}           Serveur DNS TP4 déployé avec succès !${RESET}"
echo -e "${VERT}============================================================${RESET}"
echo ""
echo "  Topologie DNS :"
echo ""
echo "  PC1 (192.168.10.10)     PC2 (192.168.20.10)"
echo "  DNS: 192.168.30.2       DNS: 192.168.30.2"
echo "       |                       |"
echo "       | 192.168.10.0/24       | 192.168.20.0/24"
echo "       v                       v"
echo "  +-------------------------------------------+"
echo "  |              GATEWAY                      |"
echo "  | gw1:.10.1 | gw2:.20.1 | gw-dns:.30.1     |"
echo "  |         IP Forwarding activé              |"
echo "  +-------------------------------------------+"
echo "                    |"
echo "                    | 192.168.30.0/24"
echo "                    v"
echo "          DNS Server (192.168.30.2)"
echo "          Zone : lab.local"
echo "          Forwarding : 8.8.8.8 / 8.8.4.4"
echo ""
echo "  Tests à lancer :"
echo "    sudo ip netns exec PC1 ping -c 1 192.168.30.2"
echo "    sudo ip netns exec PC1 dig PC2.lab.local +short"
echo "    sudo ip netns exec PC2 dig PC1.lab.local +short"
echo "    sudo ip netns exec PC1 dig -x 192.168.30.2 +short"
echo "    sudo ip netns exec PC1 dig google.com +short"
echo ""
echo "  Debug BIND :"
echo "    sudo ip netns exec DNS named-checkconf"
echo "    sudo ip netns exec DNS named-checkzone lab.local /etc/bind/db.lab.local"
echo ""
echo "  Pour nettoyer : bash clean_dns.sh"
echo ""
