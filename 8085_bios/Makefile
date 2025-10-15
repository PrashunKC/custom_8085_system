ASSEMBLER=python3 tools/assemble.py
SRC=src/bios.asm
BUILD=build
BIN=$(BUILD)/bios.bin

# Qt/C++ build settings
CXX=g++
MOC=moc-qt5
CXXFLAGS=-std=c++17 -I. $(shell pkg-config --cflags Qt5Widgets)
LDFLAGS=$(shell pkg-config --libs Qt5Widgets)

EMULATOR_SRCS=bios_gui.cpp cpu8085.cpp
EMULATOR_OBJS=$(EMULATOR_SRCS:.cpp=.o)
EMULATOR_BIN=8085_bios_system

all: $(BIN) $(EMULATOR_BIN)

# BIOS assembly build using Python assembler
$(BIN): $(SRC) | $(BUILD)
	$(ASSEMBLER) $(SRC) $(BIN)

$(BUILD):
	mkdir -p $(BUILD)

# Emulator build
bios_gui.moc.cpp: bios_gui.cpp
	$(MOC) bios_gui.cpp -o bios_gui.moc.cpp

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(EMULATOR_BIN): $(EMULATOR_OBJS) bios_gui.moc.cpp
	$(CXX) $(EMULATOR_OBJS) -o $@ $(LDFLAGS)

# Quick build (BIOS + emulator)
quick: $(BIN)
	@echo "Building emulator..."
	@mkdir -p build
	@$(CXX) $(CXXFLAGS) -fPIC $(EMULATOR_SRCS) -o $(EMULATOR_BIN) $(LDFLAGS)

clean:
	rm -rf $(BUILD)/* $(EMULATOR_OBJS) $(EMULATOR_BIN) bios_gui.moc.cpp *.o

run: all
	./$(EMULATOR_BIN)

.PHONY: all clean quick run
