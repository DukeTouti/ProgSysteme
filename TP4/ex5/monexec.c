#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

int main(int argc, char *argv[]) {
	if (argc < 2) {
		fprintf(stderr, "Usage: %s commande [arguments]\n", argv[0]);
		exit(1);
	}

	pid_t pid = fork();

	if (pid < 0) {
		perror("fork");
		exit(1);
	}

	if (pid == 0) {
		execvp(argv[1], &argv[1]);
		perror("execvp");
		exit(1);
	}

	wait(NULL);

	return 0;
}
