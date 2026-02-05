#!/bin/bash

# Script pour générer un fichier liste.txt avec des étudiants

# Nom du fichier de sortie
fichier="liste.txt"

# Vider le fichier s'il existe déjà
> "$fichier"

# Listes de noms
noms=("Martin" "Bernard" "Faure" "Girard" "Rey" "Blanc" "Durand" "Perrin" "Morel" "Garnier"
      "Robert" "Richard" "Vial" "Roux" "Bonnet" "Guillot" "Giraud" "Michel" "Garcia" "Perroud"
      "Reynaud" "Brunet" "Laurent" "Arnaud" "Jacquet" "Gauthier" "Merle" "Revol" "Allemand" "Burtin"
      "Chardon" "Buisson" "Mollard" "Raffin" "Jullien" "Tardy" "Peyron" "Pelloux" "Mure" "Coste"
      "Ollier" "Gaillard" "Bonnevie" "Fayard" "Grenier" "Meynet" "Carrel" "Pinet" "Castel" "Mermet"
      "Achard" "Monin" "Rostaing" "Glenat" "Voiron" "Belledonne" "Gamond" "Jourdan" "Chabert" "Gonnet"
      "Teste" "Berlioz" "Fournier" "Mounier" "Mistral" "Champollion" "Stendhal" "Fourier" "Vaucanson" "Mendes"
      "Giroud" "Rousseau" "Vincent" "David" "Thomas" "Dubois" "Petit" "Duval" "Denis" "Simon"
      "Fontaine" "Chevalier" "Lambert" "Lefebvre" "Moreau" "Andre" "Mercier" "Boyer" "Guerin" "Leroy"
      "Robin" "Clement" "Morin" "Nicolas" "Henry" "Mathieu" "Gautier" "Masson" "Marchand" "Martinez")

# Filières
filieres=("L1" "L2" "L3" "M1" "M2" "3A" "4A" "5A" "PeiP 1" "PeiP 2")

# Nombre d'étudiants à générer
nb_etudiants=200

echo "Génération de $nb_etudiants étudiants dans $fichier..."

for i in $(seq 1 $nb_etudiants); do
    # Sélection aléatoire d'un nom
    nom=${noms[$RANDOM % ${#noms[@]}]}
    
    # Génération d'un âge aléatoire entre 18 et 28 ans
    age=$((18 + RANDOM % 11))
    
    # Sélection aléatoire d'une filière
    filiere=${filieres[$RANDOM % ${#filieres[@]}]}
    
    # Ajout de la ligne dans le fichier
    echo "$nom;$age;$filiere" >> "$fichier"
done

# S'assurer qu'il y a au moins un étudiant nommé "Sami"
echo "Sami;22;L3" >> "$fichier"

# S'assurer qu'il y a des étudiants de 22 ans
echo "Dumont;22;M1" >> "$fichier"
echo "Lemaire;22;L2" >> "$fichier"

# S'assurer qu'il y a des variations avec "mi"
echo "Camille;21;L3" >> "$fichier"
echo "Dimitri;23;M2" >> "$fichier"

echo "Fichier $fichier créé avec succès !"
echo "Nombre total de lignes : $(wc -l < $fichier)"
echo ""
echo "Aperçu du fichier :"
head -10 "$fichier"
