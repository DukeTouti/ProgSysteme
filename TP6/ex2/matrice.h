#ifndef MATRICE_H
#define MATRICE_H

double **allouer_matrice(int N);
void liberer_matrice(double **mat, int N);
void remplir_matrice(double **mat, int N);
void afficher_matrice(double **mat, int N);
void multiplier_sequentiel(double **A, double **B, double **C, int N);

#endif
