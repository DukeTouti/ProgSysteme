#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "clients.h"
#include "stock.h"

void *thread_client(void *arg) {
	int id = *(int *)arg;
	int prise = (rand() % 10) + 1;

	printf("[Client %d] veut prendre %d articles (stock actuel : %d)\n",
		id, prise, store.valstock);

	store.valstock -= prise;

	printf("[Client %d] a pris %d articles (stock restant : %d)\n",
		id, prise, store.valstock);

	return NULL;
}
