#include "srtf.h"

void srtf(Processus procs[], int n) {
	int total_burst = 0;
	int termines = 0;

	for (int i = 0; i < n; i++) {
		total_burst += procs[i].burst;
	}

	for (int tick = 0; tick < total_burst + MAX_TEMPS && termines < n; tick++) {
		int meilleur = -1;

		for (int i = 0; i < n; i++) {
			if (procs[i].arrivee <= tick && procs[i].restant > 0) {
				if (meilleur == -1 || procs[i].restant < procs[meilleur].restant || (procs[i].restant == procs[meilleur].restant && 
													procs[i].arrivee < procs[meilleur].arrivee)) {
					meilleur = i;
				}
			}
		}

		if (meilleur == -1) {
			continue;
		}

		procs[meilleur].restant--;

		if (procs[meilleur].restant == 0) {
			procs[meilleur].fin = tick + 1;
			termines++;
		}
	}
}
