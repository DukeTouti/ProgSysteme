#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include "max.h"
#include "threads.h"

int main(int argc, char *argv[]) {
	if (argc != 3) {
		fprintf(stderr, "Usage: %s <NE> <NT>\n", argv[0]);
		return 1;
	}

	int NE = atoi(argv[1]);
	int NT = atoi(argv[2]);
	
	/* vérification des paramètres */
	if (NE <= 0 || NT <= 0) {
		fprintf(stderr, "Erreur : NE et NT doivent être > 0\n");
		return 1;
	}
	
	if (NT > NE) {
		fprintf(stderr, "Erreur : NT (%d) ne peut pas dépasser NE (%d)\n", NT, NE);
		return 1;
	}

	srand(time(NULL));
	int *tab = malloc(NE * sizeof(int));
	for (int i = 0; i < NE; i++) {
		tab[i] = rand() % (NE * 100);
	}

	printf("Tableau : ");
	for (int i = 0; i < NE; i++) {
		printf("%d ", tab[i]);
	}
	printf("\n");

	int max = chercher_max_sequentiel(tab, NE);
	printf("[Séquentiel] Max = %d\n", max);

	free(tab);
	return 0;
}
