#ifndef MAX_H
#define MAX_H

int chercher_max_sequentiel(int *tab, int taille);

extern int global_max;
extern pthread_mutex_t mutex;

#endif
