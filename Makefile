# Directories
SRC_DIR     := c-shim
BUILD_DIR   := build-artifacts
SHADER_DIR  := kernels

# Files
SRC         := $(wildcard $(SRC_DIR)/*.m)
HEADERS     := $(wildcard $(SRC_DIR)/*.h)
OBJ         := $(patsubst $(SRC_DIR)/%.m,$(BUILD_DIR)/%.o,$(SRC))
LIB         := $(BUILD_DIR)/libmetalshim.a

# Tools
CC          := clang
CF          := clang-format -style=Chromium
AR          := ar
CFLAGS      := -c -fobjc-arc -fmodules -I$(SRC_DIR)
ARFLAGS     := rcs

# Metal shader compilation
METAL       := xcrun -sdk macosx metal
METALLIB    := xcrun -sdk macosx metallib
SHADERS     := $(wildcard $(SHADER_DIR)/*.metal)
AIR_FILES   := $(patsubst $(SHADER_DIR)/%.metal,$(BUILD_DIR)/%.air,$(SHADERS))
METALLIBS   := $(patsubst $(SHADER_DIR)/%.metal,$(BUILD_DIR)/%.metallib,$(SHADERS))

# Default target
all: format $(LIB) $(METALLIBS)

kernels: $(METALLIBS)

format:
	@echo "Formatting source files with clang-format..."
	@$(CF) -i $(SRC) $(HEADERS)

# Compile Objective-C to .o
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.m | $(BUILD_DIR)
	$(CC) $(CFLAGS) $< -o $@

# Archive into static library
$(LIB): $(OBJ)
	$(AR) $(ARFLAGS) $@ $^

# Compile .metal → .air
$(BUILD_DIR)/%.air: $(SHADER_DIR)/%.metal | $(BUILD_DIR)
	$(METAL) -o $@ -c $<

# Compile .air → .metallib
$(BUILD_DIR)/%.metallib: $(BUILD_DIR)/%.air
	$(METALLIB) $< -o $@

# Ensure build dir exists
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Clean
clean:
	rm -rf $(BUILD_DIR)

clean-kernels:
	rm -f $(BUILD_DIR)/*.air $(BUILD_DIR)/*.metallib

.PHONY: all kernels clean-kernels format clean

