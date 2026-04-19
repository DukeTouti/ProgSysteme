#!/bin/bash
# =============================================================================
# TP0 - Script de nettoyage et réinitialisation complète
# =============================================================================

VERT="\e[32m"; JAUNE="\e[33m"; BLEU="\e[34m"; RESET="\e[0m"
info() { echo -e "${BLEU}[INFO]${RESET} $1"; }
ok()   { echo -e "${VERT}[OK]${RESET}   $1"; }
warn() { echo -e "${JAUNE}[SKIP]${RESET} $1 (inexistant)"; }

echo ""
info "=== NETTOYAGE COMPLET — TP0 ==="
echo ""

info "Suppression des namespaces..."
for ns in PC1 PC2 GATEWAY ISP; do
    if ip netns list | grep -q "^${ns}"; then
        sudo ip netns del "$ns" && ok "Namespace $ns supprimé"
    else
        warn "Namespace $ns"
    fi
done

info "Suppression des liens veth résiduels..."
for lien in veth1 veth2 veth3 gw1 gw2 isp1; do
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
sudo ip netns list 2>/dev/null && echo "  (aucun)" || true
echo ""
