#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "stock.h"

Store store;

void *thread_magasin(void *arg) {
	(void)arg;

	while (1) {
		if (store.valstock < SEUIL_BAS) {
			printf("[Magasin] Stock bas (%d), réapprovisionnement de %d articles\n",
				store.valstock, REAPPRO);
			store.valstock += REAPPRO;
			printf("[Magasin] Stock après réappro : %d\n", store.valstock);
		}
		usleep(100000);
	}

	return NULL;
}
