#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <time.h>

#include "semaphores.h"
#include "nageur.h"

/* ------------------------------------------------------------------ */

static void usage(const char *prog) {
	fprintf(stderr, "Usage : %s <NB> <NP> <NC> <scenario>\n  NB       : nombre de baigneurs (processus)\n  NP       : nombre de paniers\n"
	"  NC       : nombre de cabines  (NC < NP)\n  scenario : 1 (risque blocage) | 2 (sans blocage)\n", prog);
}

/* ------------------------------------------------------------------ */

int main(int argc, char *argv[]) {
	if (argc != 5) {
		usage(argv[0]);
		return EXIT_FAILURE;
	}

	int NB = atoi(argv[1]);
	int NP = atoi(argv[2]);
	int NC = atoi(argv[3]);
	int scenario = atoi(argv[4]);

	if (NB <= 0 || NP <= 0 || NC <= 0) {
		fprintf(stderr, "Erreur : NB, NP et NC doivent etre > 0\n");
		return EXIT_FAILURE;
	}
	
	if (NC >= NP) {
		fprintf(stderr, "Erreur : NC doit etre strictement inferieur a NP\n");
		return EXIT_FAILURE;
	}

	if (scenario != 1 && scenario != 2) {
		fprintf(stderr, "Erreur : scenario doit valoir 1 ou 2\n");
		return EXIT_FAILURE;
	}

	printf("=== Piscine | NB=%d baigneurs | NP=%d paniers | NC=%d cabines | Scenario %d ===\n\n", NB, NP, NC, scenario);
	fflush(stdout);

	/* --- initialisation de la mémoire partagée et des sémaphores --- */
	SharedSems *s = sems_init(NP, NC);
	
	if (s == NULL) {
		return EXIT_FAILURE;
	}

	/* --- création des NB processus baigneurs --- */
	pid_t pids[NB];

	for (int i = 0; i < NB; i++) {
		pids[i] = fork();

		if (pids[i] < 0) {
			perror("fork");
			sems_destroy(s);
			return EXIT_FAILURE;
		}

		if (pids[i] == 0) {
			/* === processus fils : un baigneur === */
			srand(time(NULL) ^ (getpid() << 4)); /* graine unique par fils */

			if (scenario == 1) {
				scenario1_nageur(s, i);
			} else {
				scenario2_nageur(s, i);
			}

			exit(EXIT_SUCCESS);
		}
	}

	/* --- père : attendre la fin de tous les baigneurs --- */
	for (int i = 0; i < NB; i++) {
		waitpid(pids[i], NULL, 0);
	}

	printf("\n=== Tous les baigneurs ont quitte la piscine ===\n");

	sems_destroy(s);
	return EXIT_SUCCESS;
}
