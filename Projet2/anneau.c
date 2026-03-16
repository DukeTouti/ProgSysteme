#include "anneau.h"

int creer_anneau(int n, int tubes[][2]) {
	for (int i = 0; i < n; i++) {
		if (pipe(tubes[i]) == -1) {
			perror("pipe");
			exit(1);
		}
	}

	int rang = 0;

	for (int i = 1; i < n; i++) {
		pid_t pid = fork();
		if (pid < 0) {
			perror("fork");
			exit(1);
		}
		if (pid == 0) {
			rang = i;
			break;
		}
	}

	for (int i = 0; i < n; i++) {
		if (i != rang && i != (rang + 1) % n) {
			close(tubes[i][0]);
			close(tubes[i][1]);
		} else if (i == rang) {
			close(tubes[i][1]);
		} else if (i == (rang + 1) % n) {
			close(tubes[i][0]);
		}
	}

	return rang;
}

void vider_tube(int lecture) {
	int tmp;
	int flags = fcntl(lecture, F_GETFL, 0);
	fcntl(lecture, F_SETFL, flags | O_NONBLOCK);
	while (read(lecture, &tmp, sizeof(int)) > 0);
	fcntl(lecture, F_SETFL, flags);
}

/*
 * barriere :
 * Un jeton fait le tour de l'anneau.
 * Garantit que tous les processus ont terminé l'étape précédente
 * avant de passer à la suivante.
 */
void barriere(int rang, int n, int lecture, int ecriture) {
	int jeton = 1;
	if (rang == 0) {
		write(ecriture, &jeton, sizeof(int));
		read(lecture, &jeton, sizeof(int));
	} else {
		read(lecture, &jeton, sizeof(int));
		write(ecriture, &jeton, sizeof(int));
	}
}

void compter_processus(int rang, int n, int lecture, int ecriture) {
	int compteur;

	if (rang == 0) {
		compteur = 1;
		write(ecriture, &compteur, sizeof(int));
		read(lecture, &compteur, sizeof(int));
		printf("[Partie b] Nombre de processus dans l'anneau : %d\n", compteur);
	} else {
		read(lecture, &compteur, sizeof(int));
		compteur++;
		write(ecriture, &compteur, sizeof(int));
	}
}

void circuler_message(int rang, int n, int lecture, int ecriture) {
	int message;

	if (rang == 0) {
		message = 10;
		printf("[Partie c] P0 initialise le message a %d\n", message);

		while (message > 0) {
			write(ecriture, &message, sizeof(int));
			read(lecture, &message, sizeof(int));
			printf("[Partie c] P0 recoit le message : %d -> decrement -> %d\n",
			       message, message - 1);
			message--;
		}

		/* Envoie le 0 final pour signaler l'arret aux autres */
		write(ecriture, &message, sizeof(int));
		printf("[Partie c] Message = 0, arret de l'anneau\n");

		/* Attend le retour du 0 pour que tous les processus l'aient traite
		 * et que le tube de P0 soit propre avant vider_tube + barriere */
		read(lecture, &message, sizeof(int));

	} else {
		while (1) {
			read(lecture, &message, sizeof(int));
			write(ecriture, &message, sizeof(int));
			if (message == 0) break;
		}
	}
}

/*
 * circuler_pids :
 * La barriere dans le main vide le tube et synchronise tout le monde.
 * P0 envoie son PID en premier, chaque processus ajoute le sien et retransmet.
 * P0 recoit la somme finale et l'affiche.
 */
void circuler_pids(int rang, int n, int lecture, int ecriture) {
    int somme = 0;
    pid_t mon_pid = getpid();

    if (rang == 0) {
        somme = (int)mon_pid;
        printf("[Partie d] P0 PID = %d\n", (int)mon_pid);
        /* P0 envoie sa somme partielle */
        write(ecriture, &somme, sizeof(int));
        /* P0 attend le retour de la somme complete */
        read(lecture, &somme, sizeof(int));
        printf("[Partie d] Somme finale des PIDs : %d\n", somme);
        /* P0 envoie un signal de fin pour debloquer les autres */
        int fin = -1;
        write(ecriture, &fin, sizeof(int));
        /* P0 attend que le signal de fin ait fait le tour */
        read(lecture, &fin, sizeof(int));
    } else {
        /* Attendre la somme partielle */
        read(lecture, &somme, sizeof(int));
        somme += (int)mon_pid;
        write(ecriture, &somme, sizeof(int));
        printf("[Partie d] P%d PID = %d\n", rang, (int)mon_pid);
        /* Attendre et transmettre le signal de fin */
        int fin;
        read(lecture,   &fin, sizeof(int));
        write(ecriture, &fin, sizeof(int));
    }
}


/*
 * election (Chang-Roberts) :
 * Chaque processus envoie son PID dans l'anneau.
 * - Recoit un PID > sien  -> le transmet
 * - Recoit son propre PID -> il est elu, envoie -1 comme signal de fin
 * - Recoit un PID < sien  -> l'ignore (ne transmet rien)
 *
 * La terminaison : l'elu envoie -1, chaque processus qui recoit -1
 * le transmet et s'arrete. L'elu recoit son propre -1 en dernier.
 */
void election(int rang, int n, int lecture, int ecriture) {
	pid_t mon_pid = getpid();
	int candidat;
	int elu = 0;

	candidat = (int)mon_pid;
	write(ecriture, &candidat, sizeof(int));

	while (1) {
		read(lecture, &candidat, sizeof(int));

		if (candidat == -1) {
			if (!elu) {
				write(ecriture, &candidat, sizeof(int));
			}
			break;
		}

		if (candidat > (int)mon_pid) {
			write(ecriture, &candidat, sizeof(int));
		} else if (candidat == (int)mon_pid) {
			printf("[Partie e] P%d (PID=%d) est elu chef !\n", rang, (int)mon_pid);
			elu = 1;
			int fin = -1;
			write(ecriture, &fin, sizeof(int));
		}
	}
}
