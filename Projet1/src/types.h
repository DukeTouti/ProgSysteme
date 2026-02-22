#ifndef TYPES_H
#define TYPES_H

#define MAX_PROC 10
#define MAX_TEMPS 200

/*
 * Structure d'un processus.
 *
 * Champs "entree" (fournis par l'utilisateur) :
 *   nom     : identifiant lisible (ex: "P1")
 *   arrivee : instant auquel le processus entre dans la file des prets
 *   burst   : temps CPU total dont le processus a besoin
 *
 * Champs "travail" (utilises pendant la simulation) :
 *   restant : temps CPU qu'il reste a executer (modifie par SRTF et RR)
 *
 * Champs "sortie" (remplis par chaque algorithme) :
 *   fin     : instant auquel le processus termine son execution
 */
typedef struct {
	char nom[4];	/* ex: "P1", "P2" ... */
	int arrivee;	/* date d'arrivee dans le systeme */
	int burst;	/* temps CPU total requis */
	int restant;	/* temps CPU restant (pour SRTF et RR) */
	int fin;	/* date de fin d'execution (remplie par l'algo) */
} Processus;

#endif /* TYPES_H */
