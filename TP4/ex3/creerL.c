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
	pid_t pid;

	for (int i = 0 ; i < nb ; i++) {
		pid = fork();

		if (pid < 0) {
			perror("fork");
			exit(1);
		}

		if (pid == 0) {
			printf("Fils %d : PID = %d, PID père = %d\n", i + 1, getpid(), getppid());
			exit(0);
		}
	}

	for (int i = 0; i < nb; i++) {
		wait(NULL);
	}

	printf("Père : PID = %d, tous les fils ont terminé.\n", getpid());

	//printf("Père : PID = %d, le Processus Père à terminé. \n", getpid());

	return 0;
}
