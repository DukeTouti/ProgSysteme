#include "processus.h"

/*
 * copier_processus :
 * Copie champ par champ les n processus de src dans dst.
 * On reinitialise 'restant' et 'fin' pour partir d'un etat propre
 * a chaque simulation d'algorithme.
 */
void copier_processus(const Processus src[], Processus dst[], int n) {
	for (int i = 0 ; i < n ; i++) {
		dst[i] = src[i];		/* copie de tous les champs d'un coup */
		dst[i].restant = src[i].burst;  /* reinit restant = burst initial     */
		dst[i].fin = 0;			/* pas encore calcule                 */
	}
}

/*
 * reinit_restant :
 * Remet le champ 'restant' a la valeur du burst pour tous les processus.
 * Utile si on veut reutiliser un tableau deja copie sans tout recopier.
 */
void reinit_restant(Processus procs[], int n) {
	for (int i = 0 ; i < n ; i++) {
		procs[i].restant = procs[i].burst;
		procs[i].fin = 0;
	}
}
