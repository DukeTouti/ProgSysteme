#ifndef THREADS_H
#define THREADS_H

#include <pthread.h>

typedef struct {
	int *tableau;
	int start;
	int end;
	int id;
} ThreadArgs;

void creer_threads(pthread_t *tids, ThreadArgs *args, int NT, int NE, int *tab);
void attendre_threads(pthread_t *tids, int NT);

#endif
