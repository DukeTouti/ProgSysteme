#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "clients.h"
#include "stock.h"

void *thread_client(void *arg) {
	int id = *(int *)arg;
	int prise = (rand() % 10) + 1;

	pthread_mutex_lock(&store.mutex);

	while (store.valstock < prise) {
		printf("[Client %d] stock insuffisant (%d < %d), en attente...\n",
			id, store.valstock, prise);
		pthread_cond_wait(&store.cond_stock_dispo, &store.mutex);
	}

	printf("[Client %d] prend %d articles (stock actuel : %d)\n",
		id, prise, store.valstock);
	store.valstock -= prise;
	printf("[Client %d] a pris %d articles (stock restant : %d)\n",
		id, prise, store.valstock);

	if (store.valstock < SEUIL_BAS) {
		pthread_cond_signal(&store.cond_stock_bas);
	}

	pthread_mutex_unlock(&store.mutex);

	return NULL;
}
