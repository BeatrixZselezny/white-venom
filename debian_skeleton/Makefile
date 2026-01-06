# © 2026 Beatrix Zselezny. All rights reserved.
# White-Venom Security Framework

CXX       := g++
TARGET    := bin/venom_engine
SRC_DIR   := src
OBJ_DIR   := obj

INC_FLAGS := -Iinclude -Iinclude/utils -Iinclude/core -Iinclude/modules

# Hardened compile flags
CXXFLAGS  := $(INC_FLAGS) -Wall -Wextra -std=c++20 \
             -fstack-protector-strong -fstack-clash-protection \
             -D_FORTIFY_SOURCE=2 -O2 -pipe

# Hardened linker flags (static + RELRO + NOW)
LDFLAGS   := -static -Wl,-z,relro,-z,now

# Source & object files
SRC := $(shell find $(SRC_DIR) -name '*.cpp')
OBJ := $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR)/%.o,$(SRC))

# Default target
all: directories $(TARGET)

# Create required directories
directories:
	@mkdir -p $(OBJ_DIR)
	@mkdir -p $(OBJ_DIR)/utils
	@mkdir -p $(OBJ_DIR)/core
	@mkdir -p $(OBJ_DIR)/modules
	@mkdir -p bin

# Link
$(TARGET): $(OBJ)
	@echo "[LINK] Creating hardened binary: $@"
	@$(CXX) $(OBJ) -o $@ $(LDFLAGS)

# Compile
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp
	@echo "[CXX] Compiling $<"
	@mkdir -p $(dir $@)
	@$(CXX) $(CXXFLAGS) -c $< -o $@

# Cleanup
clean:
	@echo "[CLEAN] Removing build artifacts"
	@rm -rf $(OBJ_DIR) bin

.PHONY: all clean directories

