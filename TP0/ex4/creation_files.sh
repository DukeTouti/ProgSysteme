#!/bin/bash

# a. Fichiers se terminant par '5'
touch fichier5
touch test15
touch annee2025
touch doc_v5

# b. Fichiers commençant par 'annee4'
touch annee4
touch annee42
touch annee4_data
touch annee4_rapport.txt
touch annee4semestre1

# c. Fichiers commençant par 'annee4' et de 7 lettres maximum
touch annee45      # 7 lettres
touch annee4x      # 7 lettres
touch annee41      # 7 lettres

# d. Fichiers commençant par 'annee' SANS chiffre
touch annee
touch anneescolaire
touch anneeprochaine
touch annee_data

# e. Fichiers contenant 'ana'
touch analyse.txt
touch banana
touch ananas.doc
touch management
touch analyse_financiere

# f. Fichiers commençant par 'a' ou 'A'
touch apache.log
touch Application
touch Archive2024
touch admin

# Autres fichiers (pour contraste)
touch bilan2025
touch rapport3
touch donnees
touch Test123
touch zebra

echo "Fichiers créés dans ~/Bureau/UIR/3A/S6/Prog_Syst/TP0/ex4"
ls -1
