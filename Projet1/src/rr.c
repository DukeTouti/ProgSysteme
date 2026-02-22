#include "rr.h"

void round_robin(Processus procs[], int n, int quantum) {
	int file[MAX_TEMPS * MAX_PROC];
	int tete = 0;
	int queue = 0;
	int arrive[MAX_PROC] = {0};
	int t = 0;
	int termines = 0;

	for (int i = 0; i < n; i++) {
		if (procs[i].arrivee == 0) {
			file[queue++] = i;
			arrive[i] = 1;
		}
	}

	while (termines < n) {
		if (tete == queue) {
			int prochain = MAX_TEMPS;
			for (int i = 0; i < n; i++) {
				if (!arrive[i] && procs[i].arrivee < prochain) {
					prochain = procs[i].arrivee;
				}
			}
			t = prochain;
			for (int i = 0; i < n; i++) {
				if (!arrive[i] && procs[i].arrivee <= t) {
					file[queue++] = i;
					arrive[i] = 1;
				}
			}
			continue;
		}

		int idx = file[tete++];
		int exec = (procs[idx].restant < quantum) ? procs[idx].restant : quantum;
		int t_fin = t + exec;

		for (int i = 0; i < n; i++) {
			if (!arrive[i] && procs[i].arrivee <= t_fin) {
				file[queue++] = i;
				arrive[i] = 1;
			}
		}

		t = t_fin;
		procs[idx].restant -= exec;

		if (procs[idx].restant == 0) {
			procs[idx].fin = t;
			termines++;
		} else {
			file[queue++] = idx;
		}
	}
}
