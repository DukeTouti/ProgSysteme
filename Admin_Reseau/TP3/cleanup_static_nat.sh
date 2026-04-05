#!/bin/bash
# =============================================================================
# TP3 - Nettoyage et réinitialisation du NAT Statique (SNAT)
# Auteur : HATHOUTI Mohammed Taha
# =============================================================================

VERT="\e[32m"; JAUNE="\e[33m"; BLEU="\e[34m"; ROUGE="\e[31m"; RESET="\e[0m"
info() { echo -e "${BLEU}[INFO]${RESET}  $1"; }
ok()   { echo -e "${VERT}[OK]${RESET}    $1"; }
warn() { echo -e "${JAUNE}[SKIP]${RESET}  $1 (inexistant ou déjà vide)"; }

echo ""
info "=== NETTOYAGE NAT STATIQUE — TP3 (réseau TP0 préservé) ==="
echo ""

# ─── VÉRIFICATION QUE GATEWAY ET ISP EXISTENT ────────────────────────────────
for ns in GATEWAY ISP; do
    if ! sudo ip netns list 2>/dev/null | grep -q "^${ns}"; then
        echo -e "${ROUGE}[ERREUR]${RESET} Namespace $ns introuvable — rien à nettoyer."
        exit 0
    fi
done

# ─── ÉTAPE 1 : VIDER LES RÈGLES FILTER SUR GATEWAY ──────────────────────────
info "Suppression des règles iptables filter (FORWARD) sur GATEWAY..."
sudo ip netns exec GATEWAY iptables -F \
    && ok "Chaîne filter vidée (-F)" \
    || warn "iptables -F GATEWAY"

# ─── ÉTAPE 2 : VIDER LES RÈGLES NAT SUR GATEWAY ──────────────────────────────
info "Suppression des règles SNAT (POSTROUTING) sur GATEWAY..."
sudo ip netns exec GATEWAY iptables -t nat -F \
    && ok "Table NAT vidée (-t nat -F)" \
    || warn "iptables -t nat -F GATEWAY"

# ─── ÉTAPE 3 : SUPPRIMER LES CHAÎNES PERSONNALISÉES ──────────────────────────
info "Suppression des chaînes iptables personnalisées sur GATEWAY..."
sudo ip netns exec GATEWAY iptables -X \
    && ok "Chaînes personnalisées supprimées (-X)" \
    || warn "iptables -X GATEWAY"

# ─── ÉTAPE 4 : REMETTRE LA POLITIQUE FORWARD À ACCEPT ────────────────────────
info "Remise à zéro de la politique FORWARD -> ACCEPT..."
sudo ip netns exec GATEWAY iptables -P FORWARD ACCEPT \
    && ok "Politique FORWARD -> ACCEPT" \
    || warn "iptables -P FORWARD ACCEPT"

# ─── ÉTAPE 5 : SUPPRIMER LA ROUTE HÔTE /32 SUR ISP ──────────────────────────
info "Suppression de la route statique 209.165.200.227/32 sur ISP..."
if sudo ip netns exec ISP ip route show 2>/dev/null | grep -q "209.165.200.227"; then
    sudo ip netns exec ISP ip route del 209.165.200.227/32 2>/dev/null \
        && ok "Route ISP 209.165.200.227/32 supprimée" \
        || warn "Suppression route ISP"
else
    warn "Route 209.165.200.227/32 (déjà absente)"
fi

# ─── ÉTAPE 6 : VIDER LE SUIVI DE CONNEXION (conntrack) ───────────────────────
info "Suppression des entrées de suivi de connexion (conntrack) sur GATEWAY..."
if sudo ip netns exec GATEWAY conntrack -F 2>/dev/null; then
    ok "Table conntrack GATEWAY vidée"
else
    warn "conntrack GATEWAY (non installé ou table vide)"
fi

# ─── VÉRIFICATION QUE TP0 EST INTACT ─────────────────────────────────────────
echo ""
info "Vérification que le réseau TP0 est toujours intact..."
ALL_OK=true

for ns in PC1 PC2 PC3 PC4 PC5 PC6 SW1 SW2 GATEWAY ISP; do
    if sudo ip netns list 2>/dev/null | grep -q "^${ns}"; then
        ok "Namespace $ns : présent"
    else
        echo -e "${ROUGE}[ERREUR]${RESET} Namespace $ns MANQUANT"
        ALL_OK=false
    fi
done

echo ""
echo -e "${VERT}=================================================================${RESET}"
echo -e "${VERT}  Nettoyage NAT statique terminé.${RESET}"
echo -e "${VERT}=================================================================${RESET}"
echo ""
if $ALL_OK; then
    echo -e "  ${VERT}Réseau TP0 intact. Vous pouvez relancer :${RESET}"
    echo -e "    ${JAUNE}bash enable_static_nat.sh${RESET}"
else
    echo -e "  ${ROUGE}Certains namespaces TP0 manquent — relancez :${RESET}"
    echo -e "    ${JAUNE}bash setup_network.sh${RESET}"
fi
echo ""
