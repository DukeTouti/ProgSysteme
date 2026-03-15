#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>

pid_t pid_pere, pid_fils;

void handler_pere(int sig) {
	printf("Père : reçu SIGUSR1, renvoie SIGUSR2\n");
	sleep(1);
	kill(pid_fils, SIGUSR2);
}

void handler_fils(int sig) {
	printf("Fils : reçu SIGUSR2, renvoie SIGUSR1\n");
	sleep(1);
	kill(pid_pere, SIGUSR1);
}

int main() {
	pid_pere = getpid();

	pid_fils = fork();

	if (pid_fils == 0) {
		/* === FILS === */
		pid_pere = getppid();
		signal(SIGUSR2, handler_fils);
		pause(); /* attend le premier signal du père */
		exit(0);
	}

	/* === PÈRE === */
	signal(SIGUSR1, handler_pere);

	printf("Père : envoi du premier SIGUSR2\n");
	sleep(1);
	kill(pid_fils, SIGUSR2);  /* père démarre le ping-pong */

	pause(); /* attend SIGUSR1 du fils */

	wait(NULL);
	return 0;
}
