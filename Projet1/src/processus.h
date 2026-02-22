#ifndef PROCESSUS_H
#define PROCESSUS_H

#include "types.h"

/*
 * Copie n processus de src vers dst.
 * Reinitialise aussi les champs 'restant' et 'fin' de la copie
 * pour que chaque algo parte d'un etat propre.
 *
 * Parametres :
 *   src : tableau source (non modifie)
 *   dst : tableau destination (ecrase)
 *   n   : nombre de processus a copier
 */
void copier_processus(const Processus src[], Processus dst[], int n);

/*
 * Reinitialise le champ 'restant' de chaque processus
 * a la valeur de son 'burst'.
 * Utile pour SRTF et RR qui decrementent 'restant' pendant la simulation.
 *
 * Parametres :
 *   procs : tableau de processus a reinitialiser
 *   n     : nombre de processus
 */
void reinit_restant(Processus procs[], int n);

#endif
