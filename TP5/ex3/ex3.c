#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>

pid_t pid_P1;

void handler_P1(int sig) {
	if (sig == SIGUSR1) {
		printf("Processus P3 cree\n");
	} else if (sig == SIGUSR2) {
		printf("Processus P3 termine\n");
	}
}

int main() {
	pid_P1 = getpid();

	signal(SIGUSR1, handler_P1);
	signal(SIGUSR2, handler_P1);

	pid_t pid_P2 = fork(); /* P1 cree P2 */

	if (pid_P2 == 0) {
		/* === P2 === */
		pid_t pid_P3 = fork(); /* P2 cree P3 */

		if (pid_P3 == 0) {
			/* === P3 === */
			kill(pid_P1, SIGUSR1); /* signale sa creation a P1 */
			exit(0);               /* se termine */
		}

		/* P2 attend la mort de P3 */
		wait(NULL);

		/* P2 signale la mort de P3 a P1 */
		kill(pid_P1, SIGUSR2);
		exit(0);
	}

	/* === P1 === */
	wait(NULL); /* attend la mort de P2 */
	printf("Processus P2 termine\n");

	return 0;
}
