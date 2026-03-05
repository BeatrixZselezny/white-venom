# © 2026 Beatrix Zselezny. All rights reserved.
# White-Venom Security Framework - Next-Level Hardened Build

CXX       := g++
CLANG     := clang
TARGET    := bin/venom_engine
OBJ_DIR   := obj
SRC_DIR   := src
BPF_SRC   := src/core/ebpf/venom_shield.bpf.c
BPF_OBJ   := $(OBJ_DIR)/core/ebpf/venom_shield.bpf.o

INC_FLAGS := -Iinclude -Iinclude/utils -Iinclude/core -Iinclude/core/ebpf -Iinclude/modules

CXXFLAGS  := $(INC_FLAGS) -Wall -Wextra -std=c++20 -pthread \
             -fstack-protector-strong -fstack-clash-protection \
             -D_FORTIFY_SOURCE=2 -O2 -pipe -MMD -MP

BPF_FLAGS := -O2 -target bpf -g

LDFLAGS   := -Wl,-z,relro,-z,now -pthread -lbpf -lelf -lzstd -lz -lpthread -ldl

SRC := src/main.cpp \
       src/core/VenomBus.cpp \
       src/core/Scheduler.cpp \
       src/core/StreamProbe.cpp \
       src/core/SocketProbe.cpp \
       src/core/VisualMemory.cpp \
       src/core/NullScheduler.cpp \
       src/core/RawPacketProbe.cpp \
       src/core/ebpf/BpfLoader.cpp \
       src/telemetry/BusTelemetry.cpp \
       src/modules/InitSecurityModule.cpp \
       src/modules/FilesystemModule.cpp \
       src/utils/HardeningUtils.cpp

OBJ := $(patsubst src/%.cpp,$(OBJ_DIR)/%.o,$(SRC))

all: directories $(BPF_OBJ) $(TARGET)

directories:
	@mkdir -p $(OBJ_DIR)/core/ebpf $(OBJ_DIR)/telemetry $(OBJ_DIR)/modules $(OBJ_DIR)/utils bin

$(BPF_OBJ): $(BPF_SRC)
	@mkdir -p $(dir $@)
	@echo "[CLANG] Compiling eBPF Shield: $<"
	@$(CLANG) $(BPF_FLAGS) -c $< -o $@

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp
	@mkdir -p $(dir $@)
	@echo "[CXX] Compiling: $<"
	@$(CXX) $(CXXFLAGS) -c $< -o $@

-include $(OBJ:.o=.d)

$(TARGET): $(OBJ)
	@echo "[LINK] Creating hardened binary with eBPF support: $@"
	@$(CXX) $(OBJ) -o $@ $(LDFLAGS)

clean:
	@rm -rf $(OBJ_DIR) bin
	@echo "[CLEAN] Workspace cleared."

.PHONY: all directories clean
