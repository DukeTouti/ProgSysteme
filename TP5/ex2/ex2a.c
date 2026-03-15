#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>

void handler(int sig) {
	printf("Fils (PID=%d) : signal %d reçu mais ignoré\n", getpid(), sig);
}

int main() {
	pid_t fils = fork();

	if (fils == 0) {
		/* fils : déroute SIGTERM et SIGKILL */
		signal(SIGTERM, handler);
		signal(SIGKILL, handler); /* sans effet, SIGKILL ne peut pas être dérouté */

		printf("Fils (PID=%d) : en attente de signaux...\n", getpid());
		while(1) {
			pause(); /* dort jusqu'à recevoir un signal */
		}
	}

	sleep(1);

	printf("Père : envoi de SIGTERM au fils\n");
	kill(fils, SIGTERM);
	sleep(1);

	printf("Père : envoi de SIGKILL au fils\n");
	kill(fils, SIGKILL);

	wait(NULL);
	printf("Père : fils terminé\n");

	return 0;
}
