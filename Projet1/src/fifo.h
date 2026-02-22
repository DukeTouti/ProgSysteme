#ifndef FIFO_H
#define FIFO_H

#include "types.h"

/*
 * Simule l'ordonnancement FIFO sur un tableau de processus.
 * Remplit le champ 'fin' de chaque processus.
 *
 * Parametres :
 *   procs : tableau de processus (modifie : champ 'fin' rempli)
 *   n     : nombre de processus
 *
 * Precondition : les processus doivent etre tries par date d'arrivee.
 */
void fifo(Processus procs[], int n);

#endif
