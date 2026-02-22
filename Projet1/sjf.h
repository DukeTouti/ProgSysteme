#ifndef SJF_H
#define SJF_H

#include "types.h"

/*
 * Simule l'ordonnancement SJF sans preemption sur un tableau de processus.
 * Remplit le champ 'fin' de chaque processus.
 *
 * Parametres :
 *   procs : tableau de processus (modifie : champ 'fin' rempli)
 *   n     : nombre de processus
 */
void sjf(Processus procs[], int n);

#endif
