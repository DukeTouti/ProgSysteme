#!/bin/bash

# Script pour générer des fichiers de test pour l'exercice 9 (find)

echo "=== Génération de l'environnement de test pour find ==="

# Utiliser le répertoire actuel
WORK_DIR="$(pwd)"
echo "Répertoire de travail : $WORK_DIR"

# ===== a. Fichiers nommés 'passwd' =====
echo ""
echo "Création de fichiers 'passwd'..."
mkdir -p dir1/subdir1 dir2/subdir2 dir3
touch passwd
touch dir1/passwd
touch dir1/subdir1/passwd
touch dir2/passwd
touch dir3/passwd
echo "5 fichiers 'passwd' créés"

# ===== b. Fichiers avec différentes dates de modification =====
echo ""
echo "Création de fichiers avec différentes dates..."
# Fichiers récents (< 10 minutes)
touch fichier_recent1.txt
touch fichier_recent2.txt
sleep 1

# Fichiers modifiés il y a plus de 10 minutes (on simule avec touch -t)
# Format: [[CC]YY]MMDDhhmm[.ss]
touch -t 202402050800 fichier_ancien1.txt
touch -t 202402050730 fichier_ancien2.txt
touch -t 202402050700 dir1/fichier_ancien3.txt
touch -t 202402050630 dir2/fichier_ancien4.log
echo "Fichiers avec dates variées créés"

# ===== c. Fichiers de différents groupes =====
echo ""
echo "Création de fichiers de différents groupes..."
# Note: pour changer le groupe, il faut les permissions appropriées
# On crée juste des fichiers, l'utilisateur devra peut-être utiliser sudo pour certains tests

touch fichier_user1.txt
touch fichier_user2.txt
touch dir1/fichier_user3.txt

# Pour créer des fichiers du groupe root (nécessite sudo)
if [ "$EUID" -eq 0 ]; then
    touch fichier_root1.txt
    chgrp root fichier_root1.txt
    touch dir2/fichier_root2.txt
    chgrp root dir2/fichier_root2.txt
    echo "Fichiers du groupe root créés"
else
    echo "Pour créer des fichiers du groupe root, relancez avec sudo"
    echo "Les fichiers appartiennent actuellement à votre groupe"
fi

# ===== d. Fichiers de différentes tailles =====
echo ""
echo "Création de fichiers de différentes tailles..."

# Petits fichiers (< 1Mo)
dd if=/dev/zero of=petit_fichier1.bin bs=1K count=100 2>/dev/null
dd if=/dev/zero of=petit_fichier2.bin bs=1K count=500 2>/dev/null

# Fichiers moyens (entre 1Mo et 20Mo)
dd if=/dev/zero of=moyen_fichier1.bin bs=1M count=5 2>/dev/null
dd if=/dev/zero of=moyen_fichier2.bin bs=1M count=15 2>/dev/null

# Gros fichiers (> 20Mo)
dd if=/dev/zero of=gros_fichier1.bin bs=1M count=25 2>/dev/null
dd if=/dev/zero of=gros_fichier2.bin bs=1M count=50 2>/dev/null
dd if=/dev/zero of=dir1/gros_fichier3.bin bs=1M count=30 2>/dev/null

echo "Fichiers de tailles variées créés"

# ===== e. Créer des répertoires sous /etc (simulation) =====
echo ""
echo "Création d'une structure simulant /etc..."
mkdir -p etc_simulation/config etc_simulation/network etc_simulation/system
mkdir -p etc_simulation/config/app1 etc_simulation/config/app2
mkdir -p etc_simulation/network/interfaces
touch etc_simulation/config.txt
touch etc_simulation/config/settings.conf
touch etc_simulation/network/hosts
echo "Structure etc_simulation/ créée"

# ===== f. Fichiers d'utilisateurs différents =====
echo ""
echo "Création de fichiers pour différents utilisateurs..."

# Créer des fichiers appartenant à l'utilisateur actuel
touch fichier_$USER_1.txt
touch fichier_$USER_2.txt
touch dir1/fichier_$USER_3.txt

# Si on veut simuler un utilisateur 'Raimbault'
# (nécessiterait de créer l'utilisateur ou d'utiliser sudo)
if id "raimbault" &>/dev/null; then
    sudo -u raimbault touch fichier_raimbault1.txt 2>/dev/null
    sudo -u raimbault touch fichier_raimbault2.txt 2>/dev/null
    echo "Fichiers de l'utilisateur 'raimbault' créés"
else
    # Sinon on crée juste des fichiers avec ce nom
    touch fichier_raimbault1.txt
    touch fichier_raimbault2.txt
    touch dir2/fichier_raimbault3.txt
    echo "Utilisateur 'raimbault' n'existe pas, fichiers créés avec user hathouti"
fi

# ===== Fichiers et répertoires divers =====
echo ""
echo "Création de fichiers supplémentaires..."
touch README.md
touch script.sh
touch data.csv
mkdir -p images documents videos
touch images/photo1.jpg images/photo2.png
touch documents/rapport.pdf documents/notes.txt
touch videos/demo.mp4

# ===== Résumé =====
echo ""
echo "=========================================="
echo " Environnement de test créé avec succès !"
echo "=========================================="
echo ""
echo "Répertoire de travail : $WORK_DIR"
echo ""
echo "Statistiques :"
echo "- Fichiers totaux : $(find "$WORK_DIR" -type f | wc -l)"
echo "- Répertoires totaux : $(find "$WORK_DIR" -type d | wc -l)"
echo "- Fichiers 'passwd' : $(find "$WORK_DIR" -name passwd | wc -l)"
echo "- Fichiers > 20Mo : $(find "$WORK_DIR" -type f -size +20M | wc -l)"
echo ""
echo "Structure créée :"
tree -L 2 "$WORK_DIR" 2>/dev/null || find "$WORK_DIR" -maxdepth 2 -print
echo ""
