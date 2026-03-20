#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include "matrice.h"

double **allouer_matrice(int N) {
	double **mat = malloc(N * sizeof(double *));
	for (int i = 0; i < N; i++) {
		mat[i] = malloc(N * sizeof(double));
	}
	return mat;
}

void liberer_matrice(double **mat, int N) {
	for (int i = 0; i < N; i++) {
		free(mat[i]);
	}
	free(mat);
}

void remplir_matrice(double **mat, int N) {
	for (int i = 0; i < N; i++) {
		for (int j = 0; j < N; j++) {
			mat[i][j] = (double)(rand() % 100);
		}
	}
}

void afficher_matrice(double **mat, int N) {
	for (int i = 0; i < N; i++) {
		for (int j = 0; j < N; j++) {
			printf("%8.2f ", mat[i][j]);
		}
		printf("\n");
	}
}

void multiplier_sequentiel(double **A, double **B, double **C, int N) {
	for (int i = 0; i < N; i++) {
		for (int j = 0; j < N; j++) {
			double sum = 0.0;
			for (int k = 0; k < N; k++) {
				sum += A[i][k] * B[k][j];
			}
			C[i][j] = sum;
		}
	}
}
