CXX      = g++
INC_FLAGS = -Iinclude -Iinclude/utils -Iinclude/core
TARGET   = bin/venom_engine
OBJ_DIR  = obj
SRC_DIR  = src

# Hardened flags: Stack protection, Fortify, és C++20 a buszhoz
CXXFLAGS = $(INC_FLAGS) -Wall -Wextra -std=c++20 \
           -fstack-protector-strong -fstack-clash-protection \
           -D_FORTIFY_SOURCE=2 -O2 -pipe

# Static linking + RELRO + Bind Now
LDFLAGS  = -static -pthread -s -Wl,-z,relro,-z,now

# Minden szükséges forrásfájl (a busz állományaival kiegészítve)
SRC = src/main.cpp \
      src/utils/HardeningUtils.cpp \
      src/utils/VenomInitializer.cpp \
      src/utils/StringUtils.cpp \
      src/utils/ConfigTemplates.cpp \
      src/core/VenomBus.cpp \
      src/core/SafeExecutor.cpp \
      src/core/Scheduler.cpp

OBJ = $(SRC:src/%.cpp=$(OBJ_DIR)/%.o)

all: directories $(TARGET)

directories:
	@mkdir -p bin
	@mkdir -p $(OBJ_DIR)/utils
	@mkdir -p $(OBJ_DIR)/core

$(TARGET): $(OBJ)
	@echo "[LINK] Creating static hardened binary: $@"
	@$(CXX) $(OBJ) -o $@ $(LDFLAGS)

$(OBJ_DIR)/%.o: src/%.cpp
	@echo "[CXX] Compiling $<"
	@$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	@rm -rf $(OBJ_DIR) bin/

.PHONY: all clean directories
