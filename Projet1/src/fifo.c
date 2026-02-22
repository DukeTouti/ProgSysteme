#include "fifo.h"

void fifo(Processus procs[], int n) {
	int t = 0;

	for (int i = 0 ; i < n ; i++) {
		if (t < procs[i].arrivee) {
			t = procs[i].arrivee;
		}
		t += procs[i].burst;
		procs[i].fin = t;
	}
}
