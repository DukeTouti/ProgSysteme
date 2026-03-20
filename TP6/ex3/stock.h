#ifndef STOCK_H
#define STOCK_H

#include <pthread.h>

#define STOCK_INITIAL  50
#define SEUIL_BAS      10
#define REAPPRO        30
#define N_CLIENTS      15

typedef struct {
	int valstock;
	pthread_mutex_t mutex;
	pthread_cond_t cond_stock_bas;
	pthread_cond_t cond_stock_dispo;
} Store;

extern Store store;

void *thread_magasin(void *arg);

#endif
