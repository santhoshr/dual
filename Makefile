CC = clang
CFLAGS = -Wall -I./include -fobjc-arc
LDFLAGS = -framework Foundation -framework Carbon -framework ApplicationServices -framework AppKit

SRC_DIR = src
OBJ_DIR = obj
BIN_DIR = bin

SOURCES = $(wildcard $(SRC_DIR)/*.m $(SRC_DIR)/*/*.m)
OBJECTS = $(patsubst $(SRC_DIR)/%.m, $(OBJ_DIR)/%.o, $(SOURCES))
TARGET = $(BIN_DIR)/dual

.PHONY: all clean

all: directories $(TARGET)

directories:
	@mkdir -p $(OBJ_DIR) $(BIN_DIR)

$(TARGET): $(OBJECTS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.m
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -rf $(OBJ_DIR) $(BIN_DIR)
