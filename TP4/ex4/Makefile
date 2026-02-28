CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -g -D_POSIX_C_SOURCE=200809L

# Liste des exercices
EXOS = ex4 ex4_v2

# Regle par defaut : compile tous les exos
all: $(EXOS)

# Une regle par exercice
ex4: ex4.c
	$(CC) $(CFLAGS) ex4.c -o ex4
	
ex4_v2: ex4_v2.c
	$(CC) $(CFLAGS) ex4_v2.c -o ex4_v2
	
# Nettoyage des executables
clean:
	rm -f $(EXOS)

# Execution d'un exo : make run EX=ex1
run:
	./$(EX)

.PHONY: all clean run
