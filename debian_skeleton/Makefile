CXX = g++
# Hardened fordítási flagek a C++17 szabvánnyal
CXXFLAGS = -Wall -Wextra -std=c++17 -Iinclude \
           -fstack-protector-all -D_FORTIFY_SOURCE=2 \
           -O2 -pipe

# Statikus linkelés a hordozhatóságért
LDFLAGS = -static -pthread -s

# A forrásfájlok pontos helye a skeletonban
SRC = src/main.cpp src/utils/HardeningUtils.cpp src/utils/StringUtils.cpp
OBJ = $(SRC:.cpp=.o)
TARGET = bin/venom_engine

all: $(TARGET)

$(TARGET): $(OBJ)
	@mkdir -p bin
	@echo "[LINK] Creating static binary: $(TARGET)"
	@$(CXX) $(OBJ) -o $(TARGET) $(LDFLAGS)

# Automatikus szabály az objektumfájlokhoz
%.o: %.cpp
	@echo "[CXX] Compiling $<"
	@$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	@echo "[CLEAN] Cleaning up objects and binaries"
	@rm -rf bin/* src/*.o src/utils/*.o
