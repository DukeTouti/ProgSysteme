#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

int main() {
	pid_t f1, f2, f3;

	f1 = fork();
	
	if (f1 < 0) {
		perror("fork 1");
		exit(1);
	}
	
	if (f1 == 0) {
		char *args[] = {"who", NULL};
		execvp("who", args);
		perror("execvp who");
		exit(1);
	}


	f2 = fork();
	if (f2 < 0) {
		perror("fork 2");
		exit(1);
	}
	
	if (f2 == 0) {
		char *args[] = {"ps", NULL};
		execvp("ps", args);
		perror("execvp ps");
		exit(1);
	}


	f3 = fork();
	if (f3 < 0) {
		perror("fork 3");
		exit(1);
	}
	
	if (f3 == 0) {
		char *args[] = {"ls", "-l", NULL};
		execvp("ls", args);
		perror("execvp ls");
		exit(1);
	}

	wait(NULL);
	wait(NULL);
	wait(NULL);

	return 0;
}
