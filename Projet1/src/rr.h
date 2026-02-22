#ifndef RR_H
#define RR_H

#include "types.h"

/*
 * Simule l'ordonnancement Round Robin sur un tableau de processus.
 * Remplit le champ 'fin' de chaque processus.
 *
 * Parametres :
 *   procs   : tableau de processus (modifie : champs 'fin' et 'restant')
 *   n       : nombre de processus
 *   quantum : duree maximale d'execution continue avant rotation
 *
 * Note : le champ 'restant' doit etre initialise a burst avant l'appel.
 */
void round_robin(Processus procs[], int n, int quantum);

#endif
