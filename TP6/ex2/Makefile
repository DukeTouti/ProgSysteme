CC      = gcc
CFLAGS  = -Wall -Wextra -g
LDFLAGS = -lpthread

TARGET  = ex2
SRCS    = main.c matrice.c
OBJS    = $(SRCS:.c=.o)

all: $(TARGET)
	rm -f $(OBJS)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $(TARGET) $(OBJS) $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(TARGET)
