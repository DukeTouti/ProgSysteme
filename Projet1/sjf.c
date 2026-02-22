#include "sjf.h"

void sjf(Processus procs[], int n) {
	int fait[MAX_PROC] = {0};
	int t = 0;
	int planifies = 0;

	while (planifies < n) {
		int meilleur = -1;

		for (int i = 0; i < n; i++) {
			if (!fait[i] && procs[i].arrivee <= t) {
				if (meilleur == -1 || procs[i].burst < procs[meilleur].burst || (procs[i].burst == procs[meilleur].burst && 
												 procs[i].arrivee < procs[meilleur].arrivee)) {
					meilleur = i;
				}
			}
		}

		if (meilleur == -1) {
			int prochain = MAX_TEMPS;
			for (int i = 0; i < n; i++) {
				if (!fait[i] && procs[i].arrivee < prochain) {
					prochain = procs[i].arrivee;
				}
			}
			
			t = prochain;
			continue;
		}

		t += procs[meilleur].burst;
		procs[meilleur].fin = t;
		fait[meilleur] = 1;
		planifies++;
	}
}
