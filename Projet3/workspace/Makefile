# Makefile - Projet3 Piscine (version modulaire)
# Programmation Système - UIR/ESIN 2025/2026

CC      = gcc
CFLAGS  = -Wall -Wextra -g
LDFLAGS = -lpthread

TARGET  = piscine
SRCS    = main.c semaphores.c nageur.c
OBJS    = $(SRCS:.c=.o)

.PHONY: all clean test1 test2 deadlock

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)
	rm -f $(OBJS)

%.o: %.c
	$(CC) $(CFLAGS) -c $<

main.o:       main.c semaphores.h nageur.h
semaphores.o: semaphores.c semaphores.h
nageur.o:     nageur.c nageur.h semaphores.h

# --- Jeux de tests ---

# Scenario 2 : sans blocage (NB=5, NP=5, NC=3)
test2: $(TARGET)
	@echo "--- Test Scenario 2 (sans blocage) : NB=5 NP=5 NC=3 ---"
	./$(TARGET) 5 5 3 2

# Scenario 1 : risque de blocage (NB=5, NP=5, NC=3)
deadlock: $(TARGET)
	@echo "--- Test Scenario 1 (risque blocage) : NB=5 NP=5 NC=3 ---"
	./$(TARGET) 5 5 3 1

# Scenario 1 avec NB < NC : pas de blocage possible
test1: $(TARGET)
	@echo "--- Test Scenario 1 (peu baigneurs) : NB=3 NP=5 NC=3 ---"
	./$(TARGET) 3 5 3 1

clean:
	rm -f $(TARGET) $(OBJS)
