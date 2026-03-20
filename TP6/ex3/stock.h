#ifndef STOCK_H
#define STOCK_H

#define STOCK_INITIAL  50
#define SEUIL_BAS      10
#define REAPPRO        30
#define N_CLIENTS      5

typedef struct {
	int valstock;
} Store;

extern Store store;

void *thread_magasin(void *arg);

#endif
