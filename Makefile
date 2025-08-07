# Makefile for libmetalshim.a

SRC = metal_shim.m
OBJ = $(SRC:.m=.o)
LIB = libmetalshim.a
CC = clang
AR = ar
CFLAGS = -c -fobjc-arc -fmodules
ARFLAGS = rcs

all: $(LIB)

$(OBJ): $(SRC)
	$(CC) $(CFLAGS) $< -o $@

$(LIB): $(OBJ)
	$(AR) $(ARFLAGS) $@ $^

clean:
	rm -f $(OBJ) $(LIB)

.PHONY: all clean
