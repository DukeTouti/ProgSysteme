#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "nageur.h"
#include "semaphores.h"


void pause_alea(int max_ms) {
	usleep((rand() % max_ms + 100) * 1000);
}

/* ------------------------------------------------------------------ */
/*  Scénario 1 : cabine -> panier (risque d'interblocage)             */
/* ------------------------------------------------------------------ */

void scenario1_nageur(SharedSems *s, int id) {
	char buf[128];

	/* === se déshabiller : cabine d'abord, panier ensuite === */
	sem_wait(&s->cabines);
	snprintf(buf, sizeof(buf), "SC1 | occupe une cabine pour se deshabiller");
	sems_log(s, id, buf);

	pause_alea(400);

	sem_wait(&s->paniers);
	snprintf(buf, sizeof(buf), "SC1 | prend un panier");
	sems_log(s, id, buf);

	sem_post(&s->cabines);
	snprintf(buf, sizeof(buf), "SC1 | libere la cabine apres deshabillage");
	sems_log(s, id, buf);

	/* === se baigner === */
	snprintf(buf, sizeof(buf), "SC1 | se baigne...");
	sems_log(s, id, buf);
	pause_alea(800);

	/* === se rhabiller : cabine nécessaire === */
	sem_wait(&s->cabines);
	snprintf(buf, sizeof(buf), "SC1 | occupe une cabine pour se rhabiller");
	sems_log(s, id, buf);

	pause_alea(400);

	sem_post(&s->paniers);
	snprintf(buf, sizeof(buf), "SC1 | rend le panier");
	sems_log(s, id, buf);

	sem_post(&s->cabines);
	snprintf(buf, sizeof(buf), "SC1 | libere la cabine -> SORTIE");
	sems_log(s, id, buf);
}

/* ------------------------------------------------------------------ */
/*  Scénario 2 : panier -> cabine (sans blocage)                      */
/* ------------------------------------------------------------------ */

void scenario2_nageur(SharedSems *s, int id) {
	char buf[128];

	/* === se déshabiller : panier d'abord, cabine ensuite === */
	sem_wait(&s->paniers);
	snprintf(buf, sizeof(buf), "SC2 | prend un panier");
	sems_log(s, id, buf);

	sem_wait(&s->cabines);
	snprintf(buf, sizeof(buf), "SC2 | occupe une cabine pour se deshabiller");
	sems_log(s, id, buf);

	pause_alea(400);

	sem_post(&s->cabines);
	snprintf(buf, sizeof(buf), "SC2 | libere la cabine apres deshabillage");
	sems_log(s, id, buf);

	/* === se baigner === */
	snprintf(buf, sizeof(buf), "SC2 | se baigne...");
	sems_log(s, id, buf);
	pause_alea(800);

	/* === se rhabiller : cabine nécessaire === */
	sem_wait(&s->cabines);
	snprintf(buf, sizeof(buf), "SC2 | occupe une cabine pour se rhabiller");
	sems_log(s, id, buf);

	pause_alea(400);

	sem_post(&s->paniers);
	snprintf(buf, sizeof(buf), "SC2 | rend le panier");
	sems_log(s, id, buf);

	sem_post(&s->cabines);
	snprintf(buf, sizeof(buf), "SC2 | libere la cabine -> SORTIE");
	sems_log(s, id, buf);
}
