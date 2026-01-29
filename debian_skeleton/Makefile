# © 2026 Beatrix Zselezny. All rights reserved.
# White-Venom Security Framework

CXX       := g++
TARGET    := bin/venom_engine
SRC_DIR   := src
OBJ_DIR   := obj

INC_FLAGS := -Iinclude -Iinclude/utils -Iinclude/core -Iinclude/modules

# Hardened compile flags
CXXFLAGS  := $(INC_FLAGS) -Wall -Wextra -std=c++20 -pthread \
             -fstack-protector-strong -fstack-clash-protection \
             -D_FORTIFY_SOURCE=2 -O2 -pipe

# Hardened linker flags
LDFLAGS   := -static -Wl,-z,relro,-z,now -pthread

# Source files
# ITT A JAVÍTÁS: Hozzáadtuk a FilesystemModule.cpp-t a listához!
SRC := src/main.cpp \
       src/core/VenomBus.cpp \
       src/core/Scheduler.cpp \
       src/telemetry/BusTelemetry.cpp \
       src/modules/InitSecurityModule.cpp \
       src/modules/FilesystemModule.cpp

OBJ := $(patsubst %.cpp,$(OBJ_DIR)/%.o,$(notdir $(SRC)))

# Default target
all: directories $(TARGET)

# Create required directories
directories:
	@mkdir -p $(OBJ_DIR)
	@mkdir -p bin

# Link
$(TARGET): $(OBJ)
	@echo "[LINK] Creating hardened binary: $@"
	@$(CXX) $(shell find $(OBJ_DIR) -name '*.o') -o $@ $(LDFLAGS)

# Compile Rules
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp
	@echo "[CXX] Compiling $<"
	@$(CXX) $(CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/%.o: $(SRC_DIR)/core/%.cpp
	@echo "[CXX] Compiling $<"
	@$(CXX) $(CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/%.o: $(SRC_DIR)/telemetry/%.cpp
	@echo "[CXX] Compiling $<"
	@$(CXX) $(CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/%.o: $(SRC_DIR)/modules/%.cpp
	@echo "[CXX] Compiling $<"
	@$(CXX) $(CXXFLAGS) -c $< -o $@

# Cleanup
clean:
	@echo "[CLEAN] Removing build artifacts"
	@rm -rf $(OBJ_DIR) bin

.PHONY: all clean directories
