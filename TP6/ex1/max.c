#include <pthread.h>

#include "max.h"

int global_max = 0;
pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

int chercher_max_sequentiel(int *tab, int taille) {
	int max = tab[0];
	for (int i = 1; i < taille; i++) {
		if (tab[i] > max) {
			max = tab[i];
		}
	}
	return max;
}
