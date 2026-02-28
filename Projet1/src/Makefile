CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -g -D_POSIX_C_SOURCE=200809L
TARGET = projet1

F = ../tests/*

SOURCES = main.c processus.c affichage.c fifo.c sjf.c srtf.c rr.c

OBJECTS = $(SOURCES:.c=.o)

HEADERS = types.h processus.h affichage.h fifo.h sjf.h srtf.h rr.h

# Regle par defaut
all: $(TARGET)
	rm -f *.o

# Creation de l'executable
$(TARGET): $(OBJECTS)
	$(CC) $(OBJECTS) -o $(TARGET)

# Compilation des fichiers objets
%.o: %.c $(HEADERS)
	$(CC) $(CFLAGS) -c $< -o $@

# Nettoyage
clean:
	rm -f *.o

fclean: clean
	rm -f $(TARGET)

re: fclean all

# Execution mode defaut (cas1 + cas2 du projet)
run: $(TARGET)
	./$(TARGET)

# Execution avec un jeu de test : make test F=../tests/cas1_projet.txt
test: $(TARGET)
	./$(TARGET) $(F)

.PHONY: all clean fclean re run test
