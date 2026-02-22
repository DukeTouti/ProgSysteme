#include <stdio.h>
#include "affichage.h"

void afficher_resultats(const Processus procs[], int n, const char *algo_nom) {
	float sum_rotation = 0.0f;
	float sum_attente  = 0.0f;
	int rotation, attente;

	printf("\n=== %s ===\n", algo_nom);
	printf("%-6s  %-8s  %-6s  %-6s  %-10s  %-10s\n",
	   "Proc", "Arrivee", "Burst", "Fin", "Rotation", "Attente");
	printf("------------------------------------------------------------\n");

	for (int i = 0 ; i < n ; i++) {
		rotation = procs[i].fin - procs[i].arrivee;
		attente  = rotation - procs[i].burst;

		sum_rotation += rotation;
		sum_attente  += attente;

		printf("%-6s  %-8d  %-6d  %-6d  %-10d  %-10d\n", procs[i].nom, procs[i].arrivee, procs[i].burst, procs[i].fin, rotation, attente);
	}

	printf("------------------------------------------------------------\n");
	printf("Moyenne rotation : %.2f\n", sum_rotation / n);
	printf("Moyenne attente  : %.2f\n", sum_attente  / n);
}
