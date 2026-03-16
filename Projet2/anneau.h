#ifndef ANNEAU_H
#define ANNEAU_H
 
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <errno.h>
 
#define MAX_PROCS 20

/*
 * Partie a : crée n processus en anneau reliés par n tubes.
 * Retourne le rang du processus courant.
 */
int creer_anneau(int n, int tubes[][2]);

void vider_tube(int lecture);

void barriere(int rang, int n, int lecture, int ecriture);

/*
 * Partie b : P0 compte le nombre de processus dans l'anneau.
 */
void compter_processus(int rang, int n, int lecture, int ecriture);

/*
 * Partie c : fait circuler un message initialisé à 10.
 * P0 décrémente à chaque tour, arrêt quand message == 0.
 */
void circuler_message(int rang, int n, int lecture, int ecriture);

/*
 * Partie d : fait circuler les PIDs et affiche la somme.
 */
void circuler_pids(int rang, int n, int lecture, int ecriture);

/*
 * Partie e : élection du processus ayant le plus grand PID.
 * Algorithme de Chang-Roberts.
 */
void election(int rang, int n, int lecture, int ecriture);

#endif
