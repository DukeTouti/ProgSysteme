#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <pthread.h>

#include "stock.h"
#include "clients.h"

int main(void) {
	srand(time(NULL));

	store.valstock = STOCK_INITIAL;
	pthread_mutex_init(&store.mutex, NULL);
	pthread_cond_init(&store.cond_stock_bas, NULL);
	pthread_cond_init(&store.cond_stock_dispo, NULL);

	printf("[Main] Stock initial : %d\n", store.valstock);

	pthread_t tid_magasin;
	pthread_t tids_clients[N_CLIENTS];
	int ids[N_CLIENTS];

	if (pthread_create(&tid_magasin, NULL, thread_magasin, NULL) != 0) {
		fprintf(stderr, "Erreur pthread_create magasin\n");
		return 1;
	}

	for (int i = 0; i < N_CLIENTS; i++) {
		ids[i] = i;
		if (pthread_create(&tids_clients[i], NULL, thread_client, &ids[i]) != 0) {
			fprintf(stderr, "Erreur pthread_create client %d\n", i);
			return 1;
		}
	}

	for (int i = 0; i < N_CLIENTS; i++) {
		if (pthread_join(tids_clients[i], NULL) != 0) {
			fprintf(stderr, "Erreur pthread_join client %d\n", i);
			return 1;
		}
	}

	printf("[Main] Tous les clients ont terminé. Stock final : %d\n",
		store.valstock);

	pthread_cancel(tid_magasin);
	pthread_join(tid_magasin, NULL);

	pthread_mutex_destroy(&store.mutex);
	pthread_cond_destroy(&store.cond_stock_bas);
	pthread_cond_destroy(&store.cond_stock_dispo);

	return 0;
}
