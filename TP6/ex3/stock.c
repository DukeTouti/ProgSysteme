#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "stock.h"

Store store;

void *thread_magasin(void *arg) {
	(void)arg;

	while (1) {
		pthread_mutex_lock(&store.mutex);

		while (store.valstock >= SEUIL_BAS) {
			pthread_cond_wait(&store.cond_stock_bas, &store.mutex);
		}

		printf("[Magasin] Stock bas (%d), réapprovisionnement de %d articles\n",
			store.valstock, REAPPRO);
		store.valstock += REAPPRO;
		printf("[Magasin] Stock après réappro : %d\n", store.valstock);

		pthread_cond_broadcast(&store.cond_stock_dispo);
		pthread_mutex_unlock(&store.mutex);
	}

	return NULL;
}
