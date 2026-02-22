#ifndef SRTF_H
#define SRTF_H

#include "types.h"

/*
 * Simule l'ordonnancement SRTF (SJF preemptif) sur un tableau de processus.
 * Remplit le champ 'fin' de chaque processus.
 *
 * Parametres :
 *   procs : tableau de processus (modifie : champs 'fin' et 'restant')
 *   n     : nombre de processus
 *
 * Note : le champ 'restant' doit etre initialise a burst avant l'appel.
 */
void srtf(Processus procs[], int n);

#endif
