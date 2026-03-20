#include <stdio.h>
#include <stdlib.h>

#include "threads.h"

static void *thread_fn(void *arg) {
	ThreadArgs *a = (ThreadArgs *)arg;
	printf("[Thread %d] démarré (indices %d à %d)\n", a->id, a->start, a->end - 1);
	return NULL;
}

void creer_threads(pthread_t *tids, ThreadArgs *args, int NT, int NE, int *tab) {
	int taille = NE / NT;

	for (int i = 0; i < NT; i++) {
		args[i].tableau = tab;
		args[i].start = i * taille;
		args[i].end = (i == NT - 1) ? NE : (i + 1) * taille;
		args[i].id = i;

		if (pthread_create(&tids[i], NULL, thread_fn, &args[i]) != 0) {
			fprintf(stderr, "Erreur pthread_create thread %d\n", i);
			exit(1);
		}
	}
}

void attendre_threads(pthread_t *tids, int NT) {
	for (int i = 0; i < NT; i++) {
		if (pthread_join(tids[i], NULL) != 0) {
			fprintf(stderr, "Erreur pthread_join thread %d\n", i);
			exit(1);
		}
		printf("[Thread %d] terminé\n", i);
	}
}
