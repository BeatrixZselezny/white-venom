CXX = g++
CXXFLAGS = -Wall -Wextra -std=c++17 -Iinclude
LDFLAGS = -static -s

# Most már három forrásfájlunk van
SRC = src/main.cpp src/utils/HardeningUtils.cpp src/utils/StringUtils.cpp
OBJ = $(SRC:.cpp=.o)
TARGET = bin/venom_engine

all: $(TARGET)

$(TARGET): $(OBJ)
	@mkdir -p bin
	$(CXX) $(OBJ) -o $(TARGET) $(LDFLAGS)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -rf bin/* src/*.o src/utils/*.o
