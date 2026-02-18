# © 2026 Beatrix Zselezny. All rights reserved.
# White-Venom Security Framework - Hardened Build System

CXX       := g++
CLANG     := clang
TARGET    := bin/venom_engine
BPF_OBJ   := obj/venom_shield.bpf.o
OBJ_DIR   := obj
SRC_DIR   := src

# Include utak (hozzáadva az ebpf alkönyvtár is)
INC_FLAGS := -Iinclude -Iinclude/utils -Iinclude/core -Iinclude/core/ebpf -Iinclude/modules

# Hardened CXX flags
CXXFLAGS  := $(INC_FLAGS) -Wall -Wextra -std=c++20 -pthread \
             -fstack-protector-strong -fstack-clash-protection \
             -D_FORTIFY_SOURCE=2 -O2 -pipe

# eBPF specific flags
BPF_FLAGS := -O2 -target bpf -g

# Dinamikus linkelés (elhagyjuk a -static-ot), így a rendszer megoldja a függőségeket
LDFLAGS   := -Wl,-z,relro,-z,now -pthread -lbpf -lelf -lzstd -lz -lpthread -ldl

# Forrásfájlok listája (BpfLoader.cpp hozzáadva)
SRC := src/main.cpp \
       src/core/VenomBus.cpp \
       src/core/Scheduler.cpp \
       src/core/StreamProbe.cpp \
       src/core/SocketProbe.cpp \
       src/core/NullScheduler.cpp \
       src/core/ebpf/BpfLoader.cpp \
       src/telemetry/BusTelemetry.cpp \
       src/modules/InitSecurityModule.cpp \
       src/modules/FilesystemModule.cpp

# Object fájlok generálása
OBJ := $(patsubst src/%.cpp,$(OBJ_DIR)/%.o,$(SRC))

all: directories $(BPF_OBJ) $(TARGET)

directories:
	@mkdir -p $(OBJ_DIR)/core/ebpf $(OBJ_DIR)/telemetry $(OBJ_DIR)/modules bin

# eBPF Kernel program fordítása
$(BPF_OBJ): src/core/ebpf/venom_shield.bpf.c
	@echo "[CLANG] Compiling eBPF Shield: $<"
	@$(CLANG) $(BPF_FLAGS) -c $< -o $@

# Fő bináris linkelése
$(TARGET): $(OBJ)
	@echo "[LINK] Creating hardened binary with eBPF support: $@"
	@$(CXX) $(OBJ) -o $@ $(LDFLAGS)

# C++ fordítási szabály
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp
	@echo "[CXX] Compiling: $<"
	@$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	@rm -rf $(OBJ_DIR) bin
	@echo "[CLEAN] Workspace cleared."

.PHONY: all directories clean
