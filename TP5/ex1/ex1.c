#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>


#define TAILLE_MAX 256
char chaine[TAILLE_MAX];

int nbOccu(char val, int debut, int fin, char chaine[]) {
	int nb_occ = 0;
	
	for (int i = debut ; i < fin ; i++) {
		if (chaine[i] == val) {
			nb_occ++ ;
		}
	}

	return nb_occ;
}


int main(int argc, char* argv[]) {
	char val;
	
	printf ("Entrez une chaîne : ");
	fgets (chaine, TAILLE_MAX, stdin);
	
	printf ("Entrez le caractère à rechercher : ");
	scanf (" %c", &val);
	
	int taille = strlen(chaine);
	int tiers = taille / 3;
	
	/* === 1.d === */
	int fd[2];
	pipe(fd); /* fd[0] = lecture ; fd[1] = ecriture */
	
	pid_t fils1, fils2;
	/* === 1.c === int status1, status2 ; */
	
	
	fils1 = fork();
	if (fils1 == 0) {
		/* ==== 1.c ==== exit(nbOccu(val, tiers, 2*tiers, chaine)); */
		close(fd[0]);
		
		int res = nbOccu(val, tiers, 2*tiers, chaine);
		
		write(fd[1], &res, sizeof(int));
		close(fd[1]);
		exit(0);
		
	}
	
	fils2 = fork();
	if (fils2 == 0) {
		/* ==== 1.c ==== exit(nbOccu(val, 2*tiers, taille, chaine)); */
		close(fd[0]);
		
        	int res = nbOccu(val, 2*tiers, taille, chaine);
        	
        	write(fd[1], &res, sizeof(int));
        	close(fd[1]);
        	exit(0);
	}
	
	close(fd[1]);
	
	int res1, res2;
	
	read(fd[0], &res1, sizeof(int));
	read(fd[0], &res2, sizeof(int));
	close(fd[0]);
	
	
	int res_pere = nbOccu(val, 0, tiers, chaine);
	
	/* === 1.c ===
	waitpid(fils1, &status1, 0);
	waitpid(fils2, &status2, 0);
	
	int res1 = WEXITSTATUS(status1);
	int res2 = WEXITSTATUS(status2); */
	
	wait(NULL);
	wait(NULL);
	
	printf("Nombre d'occurrences de '%c' : %d\n", val, res_pere + res1 + res2);

	return 0;
}





