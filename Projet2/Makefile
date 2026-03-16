CC = gcc
CFLAGS = -g -Wall
TARGET = anneau

SOURCES = main.c anneau.c
HEADERS = anneau.h
OBJECTS = $(SOURCES:.c=.o)

all: $(TARGET)
	@rm -f $(OBJECTS)

$(TARGET): $(OBJECTS)
	$(CC) $(CFLAGS) -o $@ $^

%.o: %.c $(HEADERS)
	$(CC) $(CFLAGS) -c $< -o $@

run: all
	./$(TARGET)

clean:
	rm -f $(OBJECTS) $(TARGET)

.PHONY: all run clean
