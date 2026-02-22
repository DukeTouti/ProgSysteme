#ifndef AFFICHAGE_H
#define AFFICHAGE_H

#include "types.h"

/*
 * Affiche un tableau recapitulatif des resultats d'un algorithme :
 * pour chaque processus : fin, rotation, attente
 * puis les moyennes.
 *
 * Parametres :
 *   procs    : tableau de processus avec le champ 'fin' rempli
 *   n        : nombre de processus
 *   algo_nom : nom de l'algorithme a afficher en en-tete
 */
void afficher_resultats(const Processus procs[], int n, const char *algo_nom);

#endif
