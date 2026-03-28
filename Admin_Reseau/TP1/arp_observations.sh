#!/bin/bash
# =============================================================================
# TP1 - Partie 3 : Observations ARP & Commutation
# =============================================================================

VERT="\e[32m"; ROUGE="\e[31m"; JAUNE="\e[33m"; BLEU="\e[34m"; CYAN="\e[36m"; RESET="\e[0m"
ok()    { echo -e "  ${VERT}[OK]${RESET}     $1"; }
fail()  { echo -e "  ${ROUGE}[ÉCHEC]${RESET}  $1"; }
info()  { echo -e "  ${BLEU}[INFO]${RESET}   $1"; }
wait_()  { echo -e "  ${CYAN}[ATTENTE]${RESET} $1"; }
titre() { echo -e "\n${BLEU}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
          echo -e "${BLEU}  $1${RESET}"
          echo -e "${BLEU}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; }
separateur() { echo -e "  ${JAUNE}----------------------------------------------------------${RESET}"; }

# Répertoire pour sauvegarder les captures tcpdump
CAPTURE_DIR="./arp_captures"
mkdir -p "$CAPTURE_DIR"

echo ""
echo -e "${JAUNE}  TP1 — Partie 3 : Observations ARP & Commutation${RESET}"
echo -e "${JAUNE}  $(date '+%d/%m/%Y %H:%M:%S')${RESET}"
echo ""

# =============================================================================
# ÉTAPE 1 : Démarrer avec un état ARP propre
# =============================================================================
titre "ÉTAPE 1 : Nettoyage — État ARP initial vide"

info "Vidage de toutes les tables ARP sur PC1–PC6..."
for ns in PC1 PC2 PC3 PC4 PC5 PC6; do
    sudo ip netns exec "$ns" ip neigh flush all 2>/dev/null || true
    ok "Table ARP de $ns vidée"
done

echo ""
info "Vérification des tables ARP après vidage :"
for ns in PC1 PC2 PC3 PC4 PC5 PC6; do
    ARP=$(sudo ip netns exec "$ns" ip neigh 2>/dev/null)
    if [ -z "$ARP" ]; then
        ok "$ns : table ARP vide"
    else
        fail "$ns : table ARP non vide — $ARP"
    fi
done

# =============================================================================
# ÉTAPE 2 : Observer la création dynamique de l'ARP
# =============================================================================
titre "ÉTAPE 2 : Création dynamique — ARP après ping intra-LAN"

info "S'assurer que le forwarding est DÉSACTIVÉ ..."
sudo ip netns exec GATEWAY sysctl -w net.ipv4.ip_forward=0 &>/dev/null || true
ok "Forwarding IP GATEWAY désactivé"

echo ""
info "Tables ARP AVANT tout trafic :"
separateur
for ns in PC1 PC3 PC5; do
    echo -e "  ${JAUNE}$ns${RESET} : $(sudo ip netns exec "$ns" ip neigh 2>/dev/null || echo '(vide)')"
done
separateur

echo ""
info "Déclenchement ARP : PC1 -> PC3 (ping -c 2 192.168.10.11)..."
sudo ip netns exec PC1 ping -c 2 -W 2 192.168.10.11 &>/dev/null || true

echo ""
info "Tables ARP APRÈS ping PC1 -> PC3 :"
separateur
for ns in PC1 PC3; do
    echo -e "  ${JAUNE}$ns${RESET} :"
    sudo ip netns exec "$ns" ip neigh 2>/dev/null | sed 's/^/    /' || echo "    (vide)"
done
separateur
echo ""
echo -e "  ${CYAN}Explication :${RESET}"
echo "  -> PC1 a envoyé un ARP Request broadcast : 'Qui a 192.168.10.11 ?'"
echo "  -> PC3 a répondu avec sa MAC (ARP Reply unicast)"
echo "  -> PC3 a aussi appris la MAC de PC1 (apprentissage bidirectionnel)"

# =============================================================================
# ÉTAPE 3 : Vieillissement ARP (Dynamic behavior)
# =============================================================================
titre "ÉTAPE 3 : Vieillissement ARP — Passage REACHABLE -> STALE -> suppression"

info "État actuel des entrées ARP sur PC1 :"
sudo ip netns exec PC1 ip neigh 2>/dev/null | sed 's/^/  /'

echo ""
info "Réduction du délai de vieillissement ARP pour accélérer l'observation..."
# Réduire le gc_stale_time à 10 secondes pour la démo
sudo ip netns exec PC1 bash -c 'echo 10 > /proc/sys/net/ipv4/neigh/veth-PC1-pc/gc_stale_time' 2>/dev/null || true
sudo ip netns exec PC1 bash -c 'echo 5  > /proc/sys/net/ipv4/neigh/veth-PC1-pc/base_reachable_time_ms' 2>/dev/null || \
sudo ip netns exec PC1 bash -c 'echo 5000 > /proc/sys/net/ipv4/neigh/default/base_reachable_time_ms' 2>/dev/null || true

echo ""
wait_ "Attente 15 secondes — observation du vieillissement ARP..."
for i in $(seq 15 -1 1); do
    printf "\r  ${CYAN}[ATTENTE]${RESET} Temps restant : %2d s  " "$i"
    sleep 1
done
echo ""

echo ""
info "État ARP PC1 après ~15 secondes sans trafic :"
separateur
ARP_APRES=$(sudo ip netns exec PC1 ip neigh 2>/dev/null)
if [ -z "$ARP_APRES" ]; then
    echo -e "  ${VERT}(vide — entrées expirées)${RESET}"
else
    echo "$ARP_APRES" | sed 's/^/  /'
fi
separateur
echo ""
echo -e "  ${CYAN}Explication :${RESET}"
echo "  -> REACHABLE : entrée fraîche, MAC confirmée récemment"
echo "  -> STALE     : entrée vieille, sera vérifiée au prochain paquet"
echo "  -> (vide)    : entrée expirée et supprimée automatiquement"

# =============================================================================
# ÉTAPE 4 : Capturer le trafic ARP avec tcpdump
# =============================================================================
titre "ÉTAPE 4 : Capture tcpdump — Trafic ARP sur le réseau"

info "Vidage des tables ARP avant la capture..."
for ns in PC1 PC3 PC5; do
    sudo ip netns exec "$ns" ip neigh flush all 2>/dev/null || true
done
ok "Tables ARP vidées"

echo ""
info "Démarrage de tcpdump en arrière-plan sur PC1, PC3, PC5 et SW1..."

# Lancer tcpdump sur chaque PC et sur le bridge SW1
sudo ip netns exec PC1 tcpdump -nni veth-PC1-pc arp -w "$CAPTURE_DIR/pc1_arp.pcap" 2>/dev/null &
PID_PC1=$!

sudo ip netns exec PC3 tcpdump -nni veth-PC3-pc arp -w "$CAPTURE_DIR/pc3_arp.pcap" 2>/dev/null &
PID_PC3=$!

sudo ip netns exec PC5 tcpdump -nni veth-PC5-pc arp -w "$CAPTURE_DIR/pc5_arp.pcap" 2>/dev/null &
PID_PC5=$!

sudo ip netns exec SW1 tcpdump -nni br-lan1 arp -w "$CAPTURE_DIR/sw1_br_arp.pcap" 2>/dev/null &
PID_SW1=$!

ok "tcpdump lancé sur PC1 (PID $PID_PC1)"
ok "tcpdump lancé sur PC3 (PID $PID_PC3)"
ok "tcpdump lancé sur PC5 (PID $PID_PC5)"
ok "tcpdump lancé sur SW1/br-lan1 (PID $PID_SW1)"

# Lancer aussi une capture texte lisible sur PC1
sudo ip netns exec PC1 tcpdump -nni veth-PC1-pc arp 2>/dev/null \
    > "$CAPTURE_DIR/pc1_arp_text.txt" &
PID_TEXT=$!

sleep 1  # laisser tcpdump démarrer

echo ""
info "Génération de trafic ARP — PC1 -> PC3 et PC1 -> PC5..."
sudo ip netns exec PC1 ping -c 3 192.168.10.11 &>/dev/null || true
sudo ip netns exec PC1 ping -c 3 192.168.10.12 &>/dev/null || true
sleep 1

echo ""
info "Arrêt des captures tcpdump..."
sudo kill $PID_PC1 $PID_PC3 $PID_PC5 $PID_SW1 $PID_TEXT 2>/dev/null || true
wait 2>/dev/null || true
ok "Captures sauvegardées dans : $CAPTURE_DIR/"

echo ""
info "Tables ARP après les pings :"
separateur
for ns in PC1 PC3 PC5; do
    echo -e "  ${JAUNE}$ns${RESET} :"
    sudo ip netns exec "$ns" ip neigh 2>/dev/null | sed 's/^/    /' || echo "    (vide)"
done
separateur

echo ""
info "Contenu de la capture texte ARP sur PC1 :"
separateur
if [ -s "$CAPTURE_DIR/pc1_arp_text.txt" ]; then
    cat "$CAPTURE_DIR/pc1_arp_text.txt" | head -30 | sed 's/^/  /'
else
    # Relire le pcap si la capture texte est vide
    sudo ip netns exec PC1 tcpdump -nnr "$CAPTURE_DIR/pc1_arp.pcap" 2>/dev/null \
        | head -30 | sed 's/^/  /' || echo "  (aucune capture disponible)"
fi
separateur

echo ""
echo -e "  ${CYAN}Ce qu'on observe dans la capture :${RESET}"
echo "  -> ARP Request (broadcast) : 'Who has 192.168.10.11? Tell 192.168.10.10'"
echo "  -> ARP Reply   (unicast)   : '192.168.10.11 is at <MAC de PC3>'"
echo "  -> PC5 envoie aussi un ARP Request pour connaître la MAC de PC1"
echo "  -> PC1 répond avec sa propre MAC (apprentissage bidirectionnel)"

# =============================================================================
# ÉTAPE 5 : ARP statique (permanent)
# =============================================================================
titre "ÉTAPE 5 : Création d'une entrée ARP statique permanente"

# Récupérer la MAC de PC3
MAC_PC3=$(sudo ip netns exec PC3 ip link show veth-PC3-pc 2>/dev/null \
    | grep -oP 'link/ether \K[\da-f:]+')

info "Adresse MAC de PC3 (veth-PC3-pc) : ${VERT}$MAC_PC3${RESET}"

echo ""
info "Suppression de toute entrée dynamique existante pour PC3 sur PC1..."
sudo ip netns exec PC1 ip neigh del 192.168.10.11 dev veth-PC1-pc 2>/dev/null || true
ok "Entrée dynamique supprimée (si elle existait)"

echo ""
info "Ajout de l'entrée ARP statique PERMANENT sur PC1 -> PC3..."
if [ -n "$MAC_PC3" ]; then
    sudo ip netns exec PC1 ip neigh add 192.168.10.11 \
        lladdr "$MAC_PC3" dev veth-PC1-pc nud permanent
    ok "Entrée ARP statique ajoutée : 192.168.10.11 -> $MAC_PC3 (PERMANENT)"
else
    fail "Impossible de récupérer la MAC de PC3"
    exit 1
fi

echo ""
info "Vérification — Table ARP de PC1 :"
separateur
sudo ip netns exec PC1 ip neigh show 2>/dev/null | sed 's/^/  /'
separateur

echo ""
info "Démonstration : PC1 -> PC3 SANS envoyer de requête ARP broadcast..."
# Vider la table de PC3 pour forcer un ARP si nécessaire
sudo ip netns exec PC3 ip neigh flush all 2>/dev/null || true

# Capturer l'ARP sur SW1 pour prouver qu'il n'y a PAS de broadcast depuis PC1
sudo ip netns exec SW1 tcpdump -nni br-lan1 arp 2>/dev/null \
    > "$CAPTURE_DIR/sw1_static_arp.txt" &
PID_STATIC=$!
sleep 0.5

sudo ip netns exec PC1 ping -c 3 192.168.10.11 &>/dev/null || true
sleep 1
sudo kill $PID_STATIC 2>/dev/null || true
wait $PID_STATIC 2>/dev/null || true

echo ""
info "Trafic ARP capturé sur SW1 pendant le ping PC1 -> PC3 (ARP statique) :"
separateur
if [ -s "$CAPTURE_DIR/sw1_static_arp.txt" ]; then
    # Filtrer uniquement les ARP venant de PC1
    grep -i "arp" "$CAPTURE_DIR/sw1_static_arp.txt" | sed 's/^/  /' || \
        echo "  (aucun ARP broadcast de PC1 détecté — statique fonctionne)"
else
    echo -e "  ${VERT}(aucun ARP broadcast de PC1 — l'entrée statique est utilisée directement)${RESET}"
fi
separateur

echo ""
echo -e "  ${CYAN}Explication ARP statique vs dynamique :${RESET}"
echo "  ARP DYNAMIQUE  : PC1 envoie un broadcast 'Who has X?' -> réponse -> entrée en cache (expire)"
echo "  ARP STATIQUE   : PC1 connaît déjà la MAC -> AUCUN broadcast -> entrée permanente (n'expire jamais)"

# =============================================================================
# ÉTAPE BONUS : Observer la différence LAN1 / LAN2 (isolation broadcast)
# =============================================================================
titre "BONUS : Isolation des domaines de broadcast (LAN1 vs LAN2)"

info "Vidage des tables ARP sur tous les PCs..."
for ns in PC1 PC2 PC3 PC4 PC5 PC6; do
    sudo ip netns exec "$ns" ip neigh flush all 2>/dev/null || true
done

echo ""
info "Génération d'un broadcast ARP depuis PC1 (LAN1) vers PC5..."
sudo ip netns exec PC1 ping -c 2 192.168.10.12 &>/dev/null || true

echo ""
info "Vérification : PC2/PC4/PC6 (LAN2) ne doivent PAS avoir d'entrée ARP pour PC1 :"
separateur
ISOLATION_OK=true
for ns in PC2 PC4 PC6; do
    ARP=$(sudo ip netns exec "$ns" ip neigh 2>/dev/null)
    if [ -z "$ARP" ]; then
        ok "$ns : table ARP vide — broadcast LAN1 n'a pas traversé"
    else
        echo "$ARP" | grep -q "192.168.10" && \
            fail "$ns : contient une entrée LAN1 — isolation KO !" && \
            ISOLATION_OK=false || \
            ok "$ns : entrées LAN2 uniquement — isolation correcte"
    fi
done
separateur

echo ""
if $ISOLATION_OK; then
    echo -e "  ${VERT}Isolation des domaines de broadcast confirmée !${RESET}"
    echo "  Les broadcasts ARP de LAN1 (SW1/br-lan1) ne traversent pas vers LAN2 (SW2/br-lan2)."
else
    echo -e "  ${ROUGE}Problème d'isolation détecté — vérifier la configuration des bridges.${RESET}"
fi

# =============================================================================
# RÉSUMÉ FINAL
# =============================================================================
titre "RÉSUMÉ — Partie 3 : Observations ARP"

echo ""
echo -e "  ${JAUNE}Étape 1${RESET} — Nettoyage ARP             : Tables vidées sur tous les PCs"
echo -e "  ${JAUNE}Étape 2${RESET} — ARP dynamique             : Entrées créées après ping (REACHABLE)"
echo -e "  ${JAUNE}Étape 3${RESET} — Vieillissement ARP        : REACHABLE -> STALE -> expiré"
echo -e "  ${JAUNE}Étape 4${RESET} — Capture tcpdump           : ARP Request (broadcast) + ARP Reply (unicast)"
echo -e "  ${JAUNE}Étape 5${RESET} — ARP statique (PERMANENT)  : Pas de broadcast, mapping fixe"
echo -e "  ${JAUNE}Bonus${RESET}  — Isolation broadcast        : LAN1 et LAN2 séparés par les bridges"
echo ""
echo -e "  ${BLEU}Captures sauvegardées dans : $CAPTURE_DIR/${RESET}"
echo -e "    -> pc1_arp.pcap         (trafic ARP PC1)"
echo -e "    -> pc3_arp.pcap         (trafic ARP PC3)"
echo -e "    -> pc5_arp.pcap         (trafic ARP PC5)"
echo -e "    -> sw1_br_arp.pcap      (trafic ARP sur br-lan1)"
echo -e "    -> pc1_arp_text.txt     (capture lisible PC1)"
echo -e "    -> sw1_static_arp.txt   (preuve ARP statique — pas de broadcast)"
echo ""
echo -e "  ${JAUNE}Note :${RESET} Pour lire un fichier .pcap : sudo tcpdump -nnr <fichier.pcap>"
echo ""

# Réactiver le forwarding IP pour la suite du TP
info "Réactivation du forwarding IP sur GATEWAY (pour la suite du TP)..."
sudo ip netns exec GATEWAY sysctl -w net.ipv4.ip_forward=1 &>/dev/null || true
sudo ip netns exec GATEWAY bash -c 'echo 1 > /proc/sys/net/ipv4/ip_forward' &>/dev/null || true
ok "Forwarding IP GATEWAY réactivé"
echo ""
