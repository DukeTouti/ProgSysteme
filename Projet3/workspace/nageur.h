#ifndef NAGEUR_H
#define NAGEUR_H

#include "semaphores.h"

/*
 * Simule une pause aléatoire entre 100 et (100 + max_ms) millisecondes.
 * Utilisé pour modéliser les durées réelles (déshabillage, baignade...).
 */
void pause_alea(int max_ms);

/*
 * Scénario 1 : le baigneur cherche une cabine AVANT de prendre un panier.
 * Ordre d'acquisition : sem_wait(cabines) -> sem_wait(paniers)
 * => Risque d'interblocage si NB >= NP et toutes les cabines sont occupées
 *    par des baigneurs en attente d'un panier.
 */
void scenario1_nageur(SharedSems *s, int id);

/*
 * Scénario 2 : le baigneur prend un panier AVANT de chercher une cabine.
 * Ordre d'acquisition : sem_wait(paniers) -> sem_wait(cabines)
 * => Sans blocage : l'ordre total d'acquisition brise toute attente circulaire.
 */
void scenario2_nageur(SharedSems *s, int id);

#endif
