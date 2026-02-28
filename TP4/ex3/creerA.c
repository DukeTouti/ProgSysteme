#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

void creer_arbre(int hauteur_restante) {
	if (hauteur_restante == 0) {
		return;
	}

	pid_t fils1, fils2;

	fils1 = fork();
	if (fils1 < 0) {
		perror("fork fils1");
		exit(1);
	}

	if (fils1 == 0) {
		printf("Fils gauche : PID = %d, PID père = %d\n", getpid(), getppid());
		creer_arbre(hauteur_restante - 1);
		wait(NULL);
		wait(NULL);
		exit(0);
	}

	fils2 = fork();
	if (fils2 < 0) {
		perror("fork fils2");
		exit(1);
	}

	if (fils2 == 0) {
		printf("Fils droit : PID = %d, PID père = %d\n", getpid(), getppid());
		creer_arbre(hauteur_restante - 1);
		wait(NULL);
		wait(NULL);
		exit(0);
	}

	wait(NULL);
	wait(NULL);
}

int main(int argc, char *argv[]) {
	if (argc != 2) {
		fprintf(stderr, "Usage: %s hauteur\n", argv[0]);
		exit(1);
	}

	int hauteur = atoi(argv[1]);

	printf("Racine : PID = %d\n", getpid());
	creer_arbre(hauteur);

	return 0;
}
