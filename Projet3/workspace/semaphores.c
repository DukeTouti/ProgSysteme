#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <semaphore.h>

#include "semaphores.h"

SharedSems *sems_init(int NP, int NC) {
	SharedSems *s = mmap(NULL, sizeof(SharedSems), PROT_READ | PROT_WRITE, MAP_SHARED | MAP_ANONYMOUS, -1, 0);
	if (s == MAP_FAILED) {
		perror("mmap");
		return NULL;
	}

	/* pshared = 1 : sémaphore partagé entre processus distincts */
	if ((sem_init(&s->paniers,   1, NP) == -1) || (sem_init(&s->cabines,   1, NC) == -1) || (sem_init(&s->affichage, 1, 1)  == -1)) {
		perror("sem_init");
		munmap(s, sizeof(SharedSems));
		return NULL;
	}

	return s;
}

void sems_destroy(SharedSems *s) {
	sem_destroy(&s->paniers);
	sem_destroy(&s->cabines);
	sem_destroy(&s->affichage);
	munmap(s, sizeof(SharedSems));
}

void sems_log(SharedSems *s, int id, const char *msg) {
	sem_wait(&s->affichage);
	printf("[Baigneur %2d] %s\n", id, msg);
	fflush(stdout);
	sem_post(&s->affichage);
}









