CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -g -D_POSIX_C_SOURCE=200809L

# Liste des exercices
EXOS = ex2_1 ex2_2

# Regle par defaut : compile tous les exos
all: $(EXOS)

# Une regle par exercice
ex2_1: ex2_1.c
	$(CC) $(CFLAGS) ex2_1.c -o ex2_1
	
ex2_2: ex2_2.c
	$(CC) $(CFLAGS) ex2_2.c -o ex2_2

# Ajouter les prochains exos ici, exemple :
# ex2: ex2.c
# 	$(CC) $(CFLAGS) ex2.c -o ex2

# Nettoyage des executables
clean:
	rm -f $(EXOS)

# Execution d'un exo : make run EX=ex1
run:
	./$(EX)

.PHONY: all clean run
