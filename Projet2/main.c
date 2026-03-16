#include "anneau.h"

int main(int argc, char *argv[]) {
	if (argc != 2) {
		fprintf(stderr, "Usage: %s n\n", argv[0]);
		exit(1);
	}

	int n = atoi(argv[1]);
	if (n < 2 || n > MAX_PROCS) {
		fprintf(stderr, "Erreur : n doit etre entre 2 et %d\n", MAX_PROCS);
		exit(1);
	}

	int tubes[MAX_PROCS][2];
	int rang = creer_anneau(n, tubes);

	int lecture  = tubes[rang][0];
	int ecriture = tubes[(rang + 1) % n][1];

	/* === Partie b === */
	if (rang == 0)
		printf("=== Partie b : Comptage des processus ===\n");
	compter_processus(rang, n, lecture, ecriture);
	if (rang == 0)
		printf("\n");

	/* === Partie c === */
	if (rang == 0)
		printf("=== Partie c : Circulation d'un message ===\n");
	circuler_message(rang, n, lecture, ecriture);
	vider_tube(lecture);
	barriere(rang, n, lecture, ecriture);
	if (rang == 0)
		printf("\n");

	/* === Partie d === */
	if (rang == 0)
		printf("=== Partie d : Circulation des PIDs ===\n");
	circuler_pids(rang, n, lecture, ecriture);
	if (rang == 0)
		printf("\n");

	/* === Partie e === */
	if (rang == 0)
		printf("=== Partie e : Election (Chang-Roberts) ===\n");
	election(rang, n, lecture, ecriture);

	/* P0 attend tous ses fils */
	if (rang == 0) {
		for (int i = 1; i < n; i++) {
			wait(NULL);
		}
	}

	return 0;
}
