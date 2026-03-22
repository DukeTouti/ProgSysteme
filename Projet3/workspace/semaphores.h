#ifndef SEMAPHORES_H
#define SEMAPHORES_H

#include <semaphore.h>

/*
 * Structure des ressources partagées entre les processus baigneurs.
 * Placée dans une zone mmap(MAP_SHARED | MAP_ANONYMOUS) afin d'être
 * accessible par tous les fils après fork().
 */
typedef struct {
	sem_t paniers;    /* compteur : ressources paniers disponibles  */
	sem_t cabines;    /* compteur : ressources cabines disponibles  */
	sem_t affichage;  /* mutex   : protège les printf concurrents   */
} SharedSems;

/*
 * Alloue et initialise les sémaphores dans une zone mémoire partagée.
 * Retourne un pointeur vers la zone, ou NULL en cas d'erreur.
 */
SharedSems *sems_init(int NP, int NC);

/*
 * Détruit les sémaphores et libère la mémoire partagée.
 */
void sems_destroy(SharedSems *s);

/*
 * Affiche un message de manière atomique (protégé par sem affichage).
 */
void sems_log(SharedSems *s, int id, const char *msg);

#endif /* SEMAPHORES_H */
