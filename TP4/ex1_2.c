#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

int main() {
	pid_t fils1, fils2;
	
	fils1 = fork();
	
	if (fils1 < 0) {
		perror("Erreur fork 1");
		exit(1);
	}
	
	if (fils1 == 0) {
		for (int i = 1 ; i < 51 ; i++) {
			if (i == 1) {
				printf ("Fils 1 : [ %d,", i);
			} else if (i == 50) {
				printf (" %d ]\n\n", i);
			} else {
				printf (" %d,", i);
			}
			
		} 
		exit(0);
	}
	
	wait(NULL);
	
	fils2 = fork();
	
	if (fils2 < 0) {
		perror("Erreur fork 2");
		exit(1);
	}
	
	if (fils2 == 0) {
		for (int i = 51 ; i <= 100 ; i++) {
			if (i == 51) {
				printf ("Fils 2 : [ %d,", i);
			} else if (i == 100) {
				printf (" %d ]\n\n", i);
			} else {
				printf (" %d,", i);
			}
		} 
		exit(0);
	}
	
	wait(NULL);
	
	printf("Père : les deux fils ont terminé.\n");
	
	return 0;
}
