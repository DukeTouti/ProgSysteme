#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include "max.h"

int main(int argc, char *argv[]) {
	if (argc != 2) {
		fprintf(stderr, "Usage: %s <NE>\n", argv[0]);
		return 1;
	}

	int NE = atoi(argv[1]);
	//int NT = atoi(argv[2]);

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
