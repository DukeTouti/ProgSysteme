#include <stdio.h>
#include <stdlib.h>
#include "processus.h"
#include "affichage.h"
#include "fifo.h"
#include "sjf.h"
#include "srtf.h"
#include "rr.h"

static void execute_tous_algos(const Processus base[], int n) {
	Processus copie[MAX_PROC];

	copier_processus(base, copie, n);
	fifo(copie, n);
	afficher_resultats(copie, n, "FIFO (First In First Out)");

	copier_processus(base, copie, n);
	sjf(copie, n);
	afficher_resultats(copie, n, "SJF (Shortest Job First, sans preemption)");

	copier_processus(base, copie, n);
	srtf(copie, n);
	afficher_resultats(copie, n, "SRTF (Shortest Remaining Time First, preemptif)");

	copier_processus(base, copie, n);
	round_robin(copie, n, 2);
	afficher_resultats(copie, n, "Round Robin (quantum = 2)");
}

/*
 * Charge un fichier de jeu de test.
 *
 * Format attendu (une ligne par processus) :
 *   nom arrivee burst
 *
 * Exemple :
 *   P1 0 7
 *   P2 2 4
 *
 * Retourne le nombre de processus lus, -1 en cas d'erreur.
 */
static int charger_fichier(const char *chemin, Processus procs[]) {
	FILE *f = fopen(chemin, "r");
	if (!f) {
		fprintf(stderr, "Erreur : impossible d'ouvrir '%s'\n", chemin);
		return -1;
	}

	int n = 0;
	while (n < MAX_PROC && fscanf(f, "%3s %d %d", procs[n].nom, &procs[n].arrivee, &procs[n].burst) == 3) {
		procs[n].restant = procs[n].burst;
		procs[n].fin = 0;
		n++;
	}

	fclose(f);

	if (n == 0) {
		fprintf(stderr, "Erreur : fichier vide ou format invalide\n");
		return -1;
	}

	return n;
}

int main(int argc, char *argv[]) {
	Processus procs[MAX_PROC];
	int n;

	if (argc == 2) {
		/* Mode fichier : jeu de test passe en argument */
		n = charger_fichier(argv[1], procs);
		
		if (n == -1) {
			return 1;
		}

		printf("\n");
		printf("Fichier : %s (%d processus)\n", argv[1], n);
		printf("############################################################\n");
		execute_tous_algos(procs, n);

	} else {
		/* Mode par defaut : les deux cas du projet */
		Processus cas1[4] = {
			{"P1", 0, 7, 0, 0},
			{"P2", 0, 4, 0, 0},
			{"P3", 0, 1, 0, 0},
			{"P4", 0, 4, 0, 0}
		};

		Processus cas2[4] = {
			{"P1", 0, 7, 0, 0},
			{"P2", 2, 4, 0, 0},
			{"P3", 4, 1, 0, 0},
			{"P4", 5, 4, 0, 0}
		};

		printf("\n");
		printf("############################################################\n");
		printf("#         CAS 1 : tous les processus arrivent a t=0        #\n");
		printf("############################################################\n");
		execute_tous_algos(cas1, 4);

		printf("\n");
		printf("############################################################\n");
		printf("#     CAS 2 : arrivees echelonnees (t=0, t=2, t=4, t=5)    #\n");
		printf("############################################################\n");
		execute_tous_algos(cas2, 4);
	}

	printf("\n");
	return 0;
}
