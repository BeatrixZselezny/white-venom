# © 2026 Beatrix Zselezny. All rights reserved. [cite: 270]
# White-Venom Security Framework - Hardened Build System

CXX       := g++
TARGET    := bin/venom_engine
SRC_DIR   := src
OBJ_DIR   := obj

INC_FLAGS := -Iinclude -Iinclude/utils -Iinclude/core -Iinclude/modules

# Hardened compile flags [cite: 28, 29, 30]
CXXFLAGS  := $(INC_FLAGS) -Wall -Wextra -std=c++20 -pthread \
             -fstack-protector-strong -fstack-clash-protection \
             -D_FORTIFY_SOURCE=2 -O2 -pipe

# Hardened linker flags [cite: 31, 32]
LDFLAGS   := -static -Wl,-z,relro,-z,now -pthread

# Source files - BŐVÍTVE A SOCKETPROBE MODULLAL [cite: 271]
SRC := src/main.cpp \
       src/core/VenomBus.cpp \
       src/core/Scheduler.cpp \
       src/core/StreamProbe.cpp \
       src/core/SocketProbe.cpp \
       src/core/NullScheduler.cpp \
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

# Link [cite: 31, 34]
$(TARGET): $(OBJ)
	@echo "[LINK] Creating hardened binary: $@"
	@$(CXX) $(shell find $(OBJ_DIR) -name '*.o') -o $@ $(LDFLAGS)

# Compile Rules [cite: 272]
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp
	@echo "[CXX] Compiling main $<"
	@$(CXX) $(CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/%.o: $(SRC_DIR)/core/%.cpp
	@echo "[CXX] Compiling core $<"
	@$(CXX) $(CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/%.o: $(SRC_DIR)/telemetry/%.cpp
	@echo "[CXX] Compiling telemetry $<"
	@$(CXX) $(CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/%.o: $(SRC_DIR)/modules/%.cpp
	@echo "[CXX] Compiling modules $<"
	@$(CXX) $(CXXFLAGS) -c $< -o $@

# Cleanup
clean:
	@echo "[CLEAN] Removing build artifacts"
	@rm -rf $(OBJ_DIR) bin

.PHONY: all clean directories
