#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <fcntl.h>

int main(int argc, char *argv[]) {
	if (argc != 2) {
		fprintf(stderr, "Usage: %s fichier\n", argv[0]);
		exit(1);
	}

	FILE *f = fopen(argv[1], "r");
	if (f == NULL) {
		perror("fopen");
		exit(1);
	}

	pid_t pid = fork();

	if (pid < 0) {
		perror("fork");
		exit(1);
	}

	int c;
	while ((c = fgetc(f)) != EOF) {
		printf("PID = %d : '%c'\n", getpid(), c);
		sleep(2);
	}

	fclose(f);

	if (pid > 0) {
		wait(NULL);
	}

	return 0;
}
