# © 2026 Beatrix Zselezny. All rights reserved.
# White-Venom Security Framework

CXX       := g++
TARGET    := bin/venom_engine
SRC_DIR   := src
OBJ_DIR   := obj

INC_FLAGS := -Iinclude -Iinclude/utils -Iinclude/core -Iinclude/modules

# Hardened compile flags
# JAVÍTÁS: -pthread hozzáadva a C++20 mellé
CXXFLAGS  := $(INC_FLAGS) -Wall -Wextra -std=c++20 -pthread \
             -fstack-protector-strong -fstack-clash-protection \
             -D_FORTIFY_SOURCE=2 -O2 -pipe

# Hardened linker flags
# JAVÍTÁS: -pthread itt is kell
LDFLAGS   := -static -Wl,-z,relro,-z,now -pthread

# Source files
# JAVÍTÁS: Csak azokat fordítjuk, amik már készen vannak!
# Ha a "find"-ot használnánk, elhasalna a régi Utils fájlokon.
SRC := src/main.cpp \
       src/core/VenomBus.cpp \
       src/core/Scheduler.cpp \
       src/telemetry/BusTelemetry.cpp \
       src/modules/InitSecurityModule.cpp

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
	# Mivel a patsubst lapította a könyvtárakat, itt a find paranccsal gyűjtjük össze az o-kat
	@$(CXX) $(shell find $(OBJ_DIR) -name '*.o') -o $@ $(LDFLAGS)

# Compile
# Figyelem: Ez a szabály most egyszerűsítve van, hogy minden src mappát lefedjen
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
