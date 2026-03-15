#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>

int main() {
	pid_t pid_fils;
	pid_t pid_pere = getpid();

	pid_fils = fork();

	if (pid_fils == 0) {
		/* === Client === */
		pid_pere = getppid();

		printf("Client : demanderverre(1)\n");
		kill(pid_pere, SIGCONT);	/* réveille le père */
		kill(getpid(), SIGSTOP);	/* le fils se met en pause */

		printf("Client : demanderverre(2)\n");
		kill(pid_pere, SIGCONT);	/* réveille le père */
		kill(getpid(), SIGSTOP);	/* le fils se met en pause */

		printf("Client : j'ai eu mes deux verres, merci !\n");
		exit(0);
	}

	/* === Serveur === */
	kill(getpid(), SIGSTOP);	/* se met en pause, attend la demande */

	printf("Serveur : servirverre(1)\n");
	kill(pid_fils, SIGCONT);	/* réveille le fils */
	kill(getpid(), SIGSTOP);	/* le pere se met en pause, attend la 2ème demande */

	printf("Serveur : servirverre(2)\n");
	kill(pid_fils, SIGCONT);	/* réveille le fils */

	wait(NULL);
	return 0;
}
