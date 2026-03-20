#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include "matrice.h"
#include "threads.h"

int main(int argc, char *argv[]) {
	if (argc != 3) {
		fprintf(stderr, "Usage: %s <N> <NT>\n", argv[0]);
		return 1;
	}

	int N = atoi(argv[1]);
	int NT = atoi(argv[2]);

	if (N <= 0 || NT <= 0) {
		fprintf(stderr, "Erreur : N et NT doivent être > 0\n");
		return 1;
	}
	if (NT > N) {
		fprintf(stderr, "Erreur : NT (%d) ne peut pas dépasser N (%d)\n", NT, N);
		return 1;
	}

	srand(time(NULL));

	double **A = allouer_matrice(N);
	double **B = allouer_matrice(N);
	double **C_seq = allouer_matrice(N);
	double **C_par = allouer_matrice(N);

	remplir_matrice(A, N);
	remplir_matrice(B, N);

	if (N <= 6) {
		printf("Matrice A :\n");
		afficher_matrice(A, N);
		printf("Matrice B :\n");
		afficher_matrice(B, N);
	}

	/* multiplication séquentielle */
	struct timespec t1, t2;
	clock_gettime(CLOCK_MONOTONIC, &t1);
	multiplier_sequentiel(A, B, C_seq, N);
	clock_gettime(CLOCK_MONOTONIC, &t2);

	long ns_seq = (t2.tv_sec - t1.tv_sec) * 1000000000
		+ (t2.tv_nsec - t1.tv_nsec);
	printf("[Séquentiel] Temps = %ld ns\n", ns_seq);

	if (N <= 6) {
		printf("Matrice C séquentielle :\n");
		afficher_matrice(C_seq, N);
	}

	/* multiplication parallèle */
	pthread_t *tids = malloc(NT * sizeof(pthread_t));
	ThreadArgs *args = malloc(NT * sizeof(ThreadArgs));

	clock_gettime(CLOCK_MONOTONIC, &t1);
	creer_threads(tids, args, NT, A, B, C_par, N);
	attendre_threads(tids, NT);
	clock_gettime(CLOCK_MONOTONIC, &t2);

	long ns_par = (t2.tv_sec - t1.tv_sec) * 1000000000 + (t2.tv_nsec - t1.tv_nsec);
	printf("[Parallèle]  Temps = %ld ns  (%d threads)\n", ns_par, NT);

	if (N <= 6) {
		printf("Matrice C parallèle :\n");
		afficher_matrice(C_par, N);
	}

	free(tids);
	free(args);
	liberer_matrice(A, N);
	liberer_matrice(B, N);
	liberer_matrice(C_seq, N);
	liberer_matrice(C_par, N);
	return 0;
}
