#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

int main(int argc, char *argv[]) {
	if (argc != 2) {
		fprintf(stderr, "Usage: %s nb\n", argv[0]);
		exit(1);
	}

	int nb = atoi(argv[1]);
	pid_t pid_initial = getpid();
	pid_t pid;

	printf("Processus initial : PID = %d\n", pid_initial);

	for (int i = 0; i < nb; i++) {
		pid = fork();

		if (pid < 0) {
			perror("fork");
			exit(1);
		}

		if (pid == 0) {
			printf("Génération %d : PID = %d, PID père = %d, PID initial = %d\n",
				i + 1, getpid(), getppid(), pid_initial);
		} else {
			wait(NULL);
			exit(0);
		}
	}

	exit(0);
}
