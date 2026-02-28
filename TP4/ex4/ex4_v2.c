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

	int fd = open(argv[1], O_RDONLY);
	if (fd < 0) {
		perror("open");
		exit(1);
	}

	pid_t pid = fork();

	if (pid < 0) {
		perror("fork");
		exit(1);
	}

	char c;
	int n;
	while ((n = read(fd, &c, 1)) > 0) {
		printf("PID = %d : '%c'\n", getpid(), c);
		sleep(2);
	}

	close(fd);

	if (pid > 0) {
		wait(NULL);
	}

	return 0;
}
