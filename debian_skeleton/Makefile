# © 2026 Beatrix Zselezny
# White Venom – Release Makefile (Debian Trixie only)

CXX       := g++
TARGET    := bin/venom_engine
SRC_DIR   := src
OBJ_DIR   := obj

# ==== HARD REQUIREMENTS ====
REQUIRED_GLIBC := 2.38

GLIBC_VER := $(shell ldd --version | head -n1 | sed 's/.* //')

ifeq ($(shell printf '%s\n%s\n' "$(REQUIRED_GLIBC)" "$(GLIBC_VER)" | sort -V | head -n1),$(REQUIRED_GLIBC))
else
$(error "White Venom requires glibc >= $(REQUIRED_GLIBC). Found $(GLIBC_VER)")
endif

# ==== INCLUDE PATHS ====
INC_FLAGS := -Iinclude -Iinclude/utils -Iinclude/core -Iinclude/modules

# ==== COMPILER HARDENING (NO FALLBACK) ====
CXXFLAGS := $(INC_FLAGS) -std=c++20 -O2 -pipe \
  -Wall -Wextra -Wpedantic \
  -fstack-protector-strong \
  -fstack-clash-protection \
  -fPIE \
  -fcf-protection=full \
  -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3 \
  -fno-plt \
  -fno-strict-overflow \
  -fno-delete-null-pointer-checks

# ==== LINKER HARDENING ====
LDFLAGS := -static -pie \
  -Wl,-z,relro \
  -Wl,-z,now \
  -Wl,-z,noexecstack \
  -Wl,--build-id=sha1 \
  -Wl,--as-needed

# ==== SOURCES ====
SRC := $(shell find $(SRC_DIR) -name '*.cpp')
OBJ := $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR)/%.o,$(SRC))

all: directories $(TARGET)

directories:
	@mkdir -p $(OBJ_DIR) $(OBJ_DIR)/utils $(OBJ_DIR)/core $(OBJ_DIR)/modules bin

$(TARGET): $(OBJ)
	@echo "[LINK] White Venom hardened binary"
	@$(CXX) $(OBJ) -o $@ $(LDFLAGS)

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp
	@echo "[CXX] $<"
	@mkdir -p $(dir $@)
	@$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	@rm -rf $(OBJ_DIR) bin

.PHONY: all clean directories

