# © 2026 Beatrix Zselezny. All rights reserved.
# White-Venom Security Framework - Next-Level Hardened Build

# ------------------------------------------------------------------
# Compiler & Tools
# ------------------------------------------------------------------
CXX       := g++
CLANG     := clang
TARGET    := bin/venom_engine
OBJ_DIR   := obj
SRC_DIR   := src
BPF_SRC   := src/core/ebpf/venom_shield.bpf.c
BPF_OBJ   := $(OBJ_DIR)/core/ebpf/venom_shield.bpf.o

# ------------------------------------------------------------------
# Include utak
# ------------------------------------------------------------------
INC_FLAGS := -Iinclude -Iinclude/utils -Iinclude/core -Iinclude/core/ebpf -Iinclude/modules

# ------------------------------------------------------------------
# Hardened C++ flags
# ------------------------------------------------------------------
CXXFLAGS  := $(INC_FLAGS) -Wall -Wextra -std=c++20 -pthread \
             -fstack-protector-strong -fstack-clash-protection \
             -D_FORTIFY_SOURCE=2 -O2 -pipe -MMD -MP

# eBPF specific flags
BPF_FLAGS := -O2 -target bpf -g

# Linker flags
LDFLAGS   := -Wl,-z,relro,-z,now -pthread -lbpf -lelf -lzstd -lz -lpthread -ldl

# ------------------------------------------------------------------
# Források
# ------------------------------------------------------------------
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

OBJ := $(patsubst src/%.cpp,$(OBJ_DIR)/%.o,$(SRC))

# ------------------------------------------------------------------
# Default target
# ------------------------------------------------------------------
all: directories $(BPF_OBJ) $(TARGET)

# ------------------------------------------------------------------
# Create directories automatically
# ------------------------------------------------------------------
directories:
	@mkdir -p $(OBJ_DIR)/core/ebpf $(OBJ_DIR)/telemetry $(OBJ_DIR)/modules bin

# ------------------------------------------------------------------
# eBPF object compilation
# ------------------------------------------------------------------
$(BPF_OBJ): $(BPF_SRC)
	@mkdir -p $(dir $@)
	@echo "[CLANG] Compiling eBPF Shield: $<"
	@$(CLANG) $(BPF_FLAGS) -c $< -o $@

# ------------------------------------------------------------------
# Compile C++ objects
# ------------------------------------------------------------------
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp
	@mkdir -p $(dir $@)
	@echo "[CXX] Compiling: $<"
	@$(CXX) $(CXXFLAGS) -c $< -o $@

# Include dependencies for header changes
-include $(OBJ:.o=.d)

# ------------------------------------------------------------------
# Link main binary
# ------------------------------------------------------------------
$(TARGET): $(OBJ)
	@echo "[LINK] Creating hardened binary with eBPF support: $@"
	@$(CXX) $(OBJ) -o $@ $(LDFLAGS)

# ------------------------------------------------------------------
# Clean workspace
# ------------------------------------------------------------------
clean:
	@rm -rf $(OBJ_DIR) bin
	@echo "[CLEAN] Workspace cleared."

# ------------------------------------------------------------------
# Phony targets
# ------------------------------------------------------------------
.PHONY: all directories clean


# ------------------------------------------------------------------
# Ferrari mode: clean + rebuild + backup + install
# ------------------------------------------------------------------

INSTALL_DIR := /usr/local/bin
INSTALL_LOG := build/install.log
BACKUP_DIR := build/backup

# Biztonságos rebuild: clean szinkron, utána all párhuzamos
rebuild:
	@$(MAKE) clean
	@$(MAKE) all -j$(nproc)
	@echo "[REBUILD] Full rebuild completed."

# Backup binary
backup: $(TARGET)
	@mkdir -p $(BACKUP_DIR)
	@cp $(TARGET) $(BACKUP_DIR)/venom_engine_$(shell date +'%Y%m%d_%H%M%S')
	@echo "[BACKUP] Binary backed up in $(BACKUP_DIR)"

# Install binary
install: $(TARGET)
	@mkdir -p $(INSTALL_DIR)
	@cp $(TARGET) $(INSTALL_DIR)/
	@echo "$(shell date +'%Y-%m-%d %H:%M:%S') - Installed $(TARGET) to $(INSTALL_DIR)" >> $(INSTALL_LOG)
	@echo "[INSTALL] Done. Log updated at $(INSTALL_LOG)"

# Ferrari mode: mindent egy parancsra
ferrari: rebuild backup install
	@echo "[FERRARI] All done. 🏎️💨"

