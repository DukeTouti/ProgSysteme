#include <stdio.h>
#include <stdlib.h>

#include "threads.h"

static void *thread_fn(void *arg) {
	ThreadArgs *a = (ThreadArgs *)arg;

	for (int i = a->start; i < a->end; i++) {
		for (int j = 0; j < a->N; j++) {
			double sum = 0.0;
			for (int k = 0; k < a->N; k++) {
				sum += a->A[i][k] * a->B[k][j];
			}
			a->C[i][j] = sum;
		}
	}

	printf("[Thread %d] lignes %d à %d terminées\n", a->id, a->start, a->end - 1);
	return NULL;
}

void creer_threads(pthread_t *tids, ThreadArgs *args, int NT,
	double **A, double **B, double **C, int N) {
	int lignes = N / NT;

	for (int i = 0; i < NT; i++) {
		args[i].A = A;
		args[i].B = B;
		args[i].C = C;
		args[i].N = N;
		args[i].start = i * lignes;
		args[i].end = (i == NT - 1) ? N : (i + 1) * lignes;
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
	}
}
