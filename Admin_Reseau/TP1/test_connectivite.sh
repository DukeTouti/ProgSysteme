#!/bin/bash
# =============================================================================
# TP0 - Script de tests de connectivité (tous scénarios du TP)
# =============================================================================

VERT="\e[32m"; ROUGE="\e[31m"; JAUNE="\e[33m"; BLEU="\e[34m"; RESET="\e[0m"
ok()    { echo -e "  ${VERT}[SUCCÈS]${RESET} $1"; }
fail()  { echo -e "  ${ROUGE}[ÉCHEC]${RESET}  $1 ${JAUNE}(voir note)${RESET}"; }
titre() { echo -e "\n${BLEU}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; \
          echo -e "${BLEU}  $1${RESET}"; \
          echo -e "${BLEU}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; }

ping_test() {
    local ns="$1" dest="$2" label="$3"
    if sudo ip netns exec "$ns" ping -4 -c 2 -W 2 "$dest" &>/dev/null 2>&1; then
        ok "$label"
        return 0
    else
        fail "$label"
        return 1
    fi
}

echo ""
echo -e "${JAUNE}  TP0 — Tests de connectivité réseau virtuel${RESET}"
echo -e "${JAUNE}  $(date '+%d/%m/%Y %H:%M:%S')${RESET}"

# ─── SCÉNARIO 1 : Namespaces ─────────────────────────────────────────────────
titre "SCÉNARIO 1 : Existence des namespaces"
echo ""
sudo ip netns list
for ns in PC1 PC2 GATEWAY ISP; do
    if sudo ip netns list | grep -q "^${ns}"; then
        ok "Namespace $ns présent"
    else
        fail "Namespace $ns MANQUANT"
    fi
done

# ─── SCÉNARIO 2 : Placement des interfaces ───────────────────────────────────
titre "SCÉNARIO 2 : Placement des interfaces"
echo ""
for ns in PC1 PC2 GATEWAY ISP; do
    IFACES=$(sudo ip netns exec "$ns" ip link show 2>/dev/null | grep -v lo | grep -oP '^\d+: \K[\w]+(?=@|:)' | tr '\n' ' ')
    echo -e "  ${JAUNE}$ns${RESET} → $IFACES"
done

# ─── SCÉNARIO 3 : Configuration IP ───────────────────────────────────────────
titre "SCÉNARIO 3 : Configuration IP"
echo ""
printf "  %-10s %-10s %s\n" "Namespace" "Interface" "Adresse IP"
printf "  %-10s %-10s %s\n" "─────────" "─────────" "──────────────────"
printf "  %-10s %-10s %s\n" "PC1" "veth1" "$(ip netns exec PC1 ip addr show veth1 2>/dev/null | grep -oP 'inet \K[\d./]+')"
printf "  %-10s %-10s %s\n" "PC2" "veth2" "$(ip netns exec PC2 ip addr show veth2 2>/dev/null | grep -oP 'inet \K[\d./]+')"
printf "  %-10s %-10s %s\n" "GATEWAY" "gw1" "$(ip netns exec GATEWAY ip addr show gw1 2>/dev/null | grep -oP 'inet \K[\d./]+')"
printf "  %-10s %-10s %s\n" "GATEWAY" "gw2" "$(ip netns exec GATEWAY ip addr show gw2 2>/dev/null | grep -oP 'inet \K[\d./]+')"
printf "  %-10s %-10s %s\n" "GATEWAY" "veth3" "$(ip netns exec GATEWAY ip addr show veth3 2>/dev/null | grep -oP 'inet \K[\d./]+')"
printf "  %-10s %-10s %s\n" "ISP" "isp1" "$(ip netns exec ISP ip addr show isp1 2>/dev/null | grep -oP 'inet \K[\d./]+')"

# ─── SCÉNARIO 4 : Connectivité locale ────────────────────────────────────────
titre "SCÉNARIO 4 : Connectivité locale (PC ↔ Passerelle)"
echo ""
ping_test PC1     192.168.10.1  "PC1 → Passerelle LAN1 (192.168.10.1)"
ping_test PC2     192.168.20.1  "PC2 → Passerelle LAN2 (192.168.20.1)"
ping_test GATEWAY 192.168.10.10 "GATEWAY → PC1 (192.168.10.10)"
ping_test GATEWAY 192.168.20.10 "GATEWAY → PC2 (192.168.20.10)"

# ─── SCÉNARIO 5 : Routage inter-LAN ─────────────────────────────────────────
titre "SCÉNARIO 5 : Routage inter-LAN (PC1 ↔ PC2)"
echo ""
ping_test PC1 192.168.20.10 "PC1 (LAN1) → PC2 (LAN2) — forwarding GATEWAY"
ping_test PC2 192.168.10.10 "PC2 (LAN2) → PC1 (LAN1) — forwarding GATEWAY"

# ─── SCÉNARIO 6 : Lien WAN ───────────────────────────────────────────────────
titre "SCÉNARIO 6 : Lien Passerelle ↔ FAI (WAN)"
echo ""
ping_test GATEWAY 209.165.200.225 "GATEWAY → ISP (209.165.200.225)"
ping_test ISP     209.165.200.226 "ISP → GATEWAY WAN (209.165.200.226)"

# ─── SCÉNARIO 7 : Bout-en-bout ───────────────────────────────────────────────
titre "SCÉNARIO 7 : Test bout-en-bout PC → FAI (sans NAT)"
echo ""

echo "  [INFO] Test PC1 → ISP (209.165.200.225) sans NAT..."
if ip netns exec PC1 ping -c 2 -W 2 209.165.200.225 &>/dev/null; then
    echo -e "  ${ROUGE}[INATTENDU]${RESET} PC1 → ISP : le ping passe alors qu'il ne devrait pas"
else
    echo -e "  ${VERT}[ATTENDU]${RESET}   PC1 → ISP : échec correct — ISP n'a pas de route retour vers 192.168.10.0/24"
fi

echo "  [INFO] Test PC2 → ISP (209.165.200.225) sans NAT..."
if ip netns exec PC2 ping -c 2 -W 2 209.165.200.225 &>/dev/null; then
    echo -e "  ${ROUGE}[INATTENDU]${RESET} PC2 → ISP : le ping passe alors qu'il ne devrait pas"
else
    echo -e "  ${VERT}[ATTENDU]${RESET}   PC2 → ISP : échec correct — ISP n'a pas de route retour vers 192.168.20.0/24"
fi

echo ""
echo -e "  ${JAUNE}Explication :${RESET} Le paquet part de PC1 → GATEWAY → ISP mais ISP"
echo -e "  ne connaît pas 192.168.10.0/24, il abandonne l'Echo Reply."
echo -e "  => Le NAT est nécessaire pour résoudre ce problème."

# ─── TABLES DE ROUTAGE ───────────────────────────────────────────────────────
titre "TABLES DE ROUTAGE"
for ns in PC1 PC2 GATEWAY ISP; do
    echo -e "\n  ${JAUNE}$ns :${RESET}"
    sudo ip netns exec "$ns" ip route | sed 's/^/    /'
done

# ─── RÉSUMÉ ───────────────────────────────────────────────────────────────────
titre "RÉSUMÉ FORWARDING IP"
echo ""
FWD_GW=$(sudo ip netns exec GATEWAY cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "?")
echo -e "  Forwarding IP sur GATEWAY : ${VERT}$FWD_GW${RESET} (1 = actif)"
echo ""
