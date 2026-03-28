#!/bin/bash
# =============================================================================
# TP1 - Script de nettoyage et réinitialisation complète
# =============================================================================

VERT="\e[32m"; JAUNE="\e[33m"; BLEU="\e[34m"; RESET="\e[0m"
info() { echo -e "${BLEU}[INFO]${RESET} $1"; }
ok()   { echo -e "${VERT}[OK]${RESET}   $1"; }
warn() { echo -e "${JAUNE}[SKIP]${RESET} $1 (inexistant)"; }

echo ""
info "=== NETTOYAGE COMPLET — TP1 ==="
echo ""

info "Suppression des namespaces..."
for ns in PC1 PC2 PC3 PC4 PC5 PC6 SW1 SW2 GATEWAY ISP; do
    if ip netns list | grep -q "^${ns}"; then
        sudo ip netns del "$ns" && ok "Namespace $ns supprimé"
    else
        warn "Namespace $ns"
    fi
done

info "Suppression des liens veth résiduels..."
for lien in veth-PC1-pc veth-PC1-sw \
            veth-PC2-pc veth-PC2-sw \
            veth-PC3-pc veth-PC3-sw \
            veth-PC4-pc veth-PC4-sw \
            veth-PC5-pc veth-PC5-sw \
            veth-PC6-pc veth-PC6-sw \
            gw-lan1 gw-lan1-sw \
            gw-lan2 gw-lan2-sw \
            veth3 isp1; do
    if ip link show "$lien" &>/dev/null; then
        sudo ip link del "$lien" 2>/dev/null && ok "Lien $lien supprimé"
    else
        warn "Lien $lien"
    fi
done

echo ""
echo -e "${VERT}=================================================================${RESET}"
echo -e "${VERT}  Environnement réinitialisé. Prêt pour un nouveau déploiement.${RESET}"
echo -e "${VERT}=================================================================${RESET}"
echo ""
info "Namespaces restants :"
REMAINING=$(sudo ip netns list 2>/dev/null)
if [ -z "$REMAINING" ]; then
    echo "  (aucun)"
else
    echo "$REMAINING" | sed 's/^/  /'
fi
echo ""
