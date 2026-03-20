#ifndef THREADS_H
#define THREADS_H

#include <pthread.h>

typedef struct {
	double **A;
	double **B;
	double **C;
	int N;
	int start;
	int end;
	int id;
} ThreadArgs;

void creer_threads(pthread_t *tids, ThreadArgs *args, int NT, double **A, double **B, double **C, int N);
void attendre_threads(pthread_t *tids, int NT);

#endif
