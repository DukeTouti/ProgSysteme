CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -g -D_POSIX_C_SOURCE=200809L

# Liste des exercices
EXOS = creerL creerP creerA

# Regle par defaut : compile tous les exos
all: $(EXOS)

# Une regle par exercice
creerL: creerL.c
	$(CC) $(CFLAGS) creerL.c -o creerL

creerP: creerP.c
	$(CC) $(CFLAGS) creerP.c -o creerP

creerA: creerA.c
	$(CC) $(CFLAGS) creerA.c -o creerA
	
# Nettoyage des executables
clean:
	rm -f $(EXOS)

# Execution d'un exo : make run EX=ex1
run:
	./$(EX)

.PHONY: all clean run
