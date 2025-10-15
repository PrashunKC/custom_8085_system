# 8085 BIOS System - Interactive Development Environment

A complete 8085 microprocessor system with integrated BIOS/monitor ROM and interactive GUI. Perfect for learning 8085 programming, developing operating systems, or testing embedded software.

## Features

### BIOS Monitor ROM
- Reset initialization with banner
- Interactive command prompt with basic commands:
  - **H**: Help - display available commands
  - **D addr len**: Dump memory in hex format
  - **M addr**: Modify memory bytes interactively
  - **G addr**: Jump to address and execute
  - **L**: Load Intel HEX programs into memory
- Console I/O via I/O ports 0 (input) and 1 (output)

### Emulator Features
- **Complete 8085 instruction set** (all 246 valid opcodes)
- **Interactive Terminal** - Type commands directly into the BIOS
- **Real-time Register Display** - Watch A, B, C, D, E, H, L, SP, PC
- **Flags Display** - Monitor S, Z, AC, P, CY flags
- **Memory Viewer** - See first 256 bytes of memory
- **Step/Run/Stop Controls** - Debug or run programs
- **Load Programs** - Load binary files for testing
- **GUI built with Qt5** - Modern, responsive interface

## Architecture

The system integrates:
- **C++ 8085 Emulator** (`cpu8085.cpp`) - Full instruction set with I/O callbacks
- **BIOS Monitor** (`src/bios.asm`) - Assembled to `build/bios.bin`, loaded at 0x0000
- **Qt5 GUI** (`bios_gui.cpp`) - Interactive terminal and system controls
- **I/O Port System** - Port 0 (console in), Port 1 (console out)

This is written in C++17 with Qt5 for the GUI, and 8080/8085-compatible assembly (using Macroassembler AS `asl`) for the BIOS.

## Assumptions and I/O contract

By default, the monitor uses two I/O ports for console:

- IN from port 0: returns the next ASCII byte if available; returns 0 if no character. The monitor busy-waits until non-zero.
- OUT to port 1: write an ASCII byte to the console output.

You can change these ports at the top of `src/bios.asm` by editing the equates `CONIN_PORT` and `CONOUT_PORT`.

If your emulator has different semantics (e.g., separate status ports), you can adapt the `con_getc` and `con_putc` routines accordingly.

## Layout

- `src/bios.asm` — Monitor BIOS source, ORG 0x0000
- `Makefile` — Build targets for .bin and .hex
- `tools/assemble.sh` — Helper script to assemble with `asl`

## Prerequisites

### Required

- **Qt5 development libraries**:
  ```bash
  sudo dnf install qt5-qtbase-devel  # Fedora
  # or
  sudo apt-get install qtbase5-dev   # Ubuntu/Debian
  ```

- **C++ compiler** (g++ 7+ or clang++)

### Optional (for building BIOS from source)

- **Macroassembler AS** (`asl`) and its `p2bin`/`p2hex` tools

  On Fedora/RHEL:
  ```bash
  sudo dnf install asl
  ```

  On Debian/Ubuntu (may need to build from source):
  ```bash
  sudo apt-get install -y build-essential bison flex
  git clone https://github.com/alfako/asl.git
  cd asl
  make
  sudo make install
  ```

## Build

### Quick Build (using Make)

```bash
cd /home/kde/Documents/8085_bios
make quick
```

This builds:
- `build/bios.bin` — BIOS ROM (assembled from `src/bios.asm`)
- `8085_bios_system` — Qt GUI emulator executable

### Alternative: CMake Build

```bash
mkdir build && cd build
cmake ..
make
```

## Run

```bash
./8085_bios_system
```

or

```bash
make run
```

## Usage

1. **Launch the emulator** - The GUI will open with an interactive terminal
2. **Click "Load BIOS"** - Loads `build/bios.bin` into memory at 0x0000
3. **Click "Run"** - The 8085 starts executing from 0x0000
4. **See the BIOS banner** in the terminal
5. **Type commands** at the `>` prompt (try `H` for help)
6. **Use BIOS commands** to dump memory, modify bytes, or load programs

### Clean

```bash
make clean
```

## BIOS Command Examples

When the BIOS monitor prompt (`>`) appears, you can use these commands:

- **H** - Display help
- **D 2000 40** - Dump 64 (0x40) bytes from address 0x2000
- **M 2100** - Modify bytes at address 0x2100
  - Enter hex bytes like `3E C3 00 10`
  - Press `.` or Enter on blank line to finish
- **G 1000** - Jump to address 0x1000 and execute
- **L** - Load Intel HEX format program
  - Paste Intel HEX records into terminal
  - Loader auto-detects EOF record

Notes:
- Hex numbers are case-insensitive
- Whitespace between hex digits is flexible
- HEX loader supports record types 00 (data) and 01 (EOF)

## Developing Your Own Programs/OS

### Method 1: Write Assembly & Load

1. Write your program in 8085 assembly (e.g., `myprogram.asm`)
2. Assemble it with your preferred assembler (asl, as85, etc.)
3. Use BIOS **L** command to load Intel HEX
4. Use BIOS **G** command to execute

### Method 2: Direct Binary Load

1. Write program in assembly, assemble to `.bin`
2. Click "Load Program..." in the GUI
3. Program loads at 0x2000 by default
4. Use BIOS command `G 2000` to execute

### Method 3: Extend the BIOS

Edit `src/bios.asm` to add:
- New monitor commands
- Device drivers
- System calls for your OS
- Boot loader logic

Then rebuild and test!

## I/O Port Configuration

The BIOS uses these I/O ports (configurable in `src/bios.asm`):

- **Port 0 (IN)**: Console input - returns ASCII character or 0 if no key pressed
- **Port 1 (OUT)**: Console output - sends ASCII character to terminal

To add more I/O devices:
- Define new port numbers in your program
- Use `IN port` / `OUT port` instructions
- Extend `cpu8085.cpp` I/O callbacks if needed for special hardware simulation

## Project Structure

```
8085_bios/
├── src/
│   └── bios.asm          # Monitor BIOS source code
├── build/
│   ├── bios.bin          # Assembled BIOS ROM
│   └── bios.hex          # Intel HEX format
├── cpu8085.h/cpp         # 8085 emulator core (from 8085_emulation project)
├── bios_gui.cpp          # Qt5 GUI with interactive terminal
├── CMakeLists.txt        # CMake build configuration
├── Makefile              # Make build configuration
└── README.md             # This file
```

## Troubleshooting

- **BIOS doesn't load**: Make sure `build/bios.bin` exists (run `make` first)
- **No terminal output**: Check that BIOS is loaded and you clicked "Run"
- **Keyboard not working**: Terminal widget should have focus; click in the terminal area
- **Assembler errors**: Check `build/bios.lst` for assembly errors
- **Emulator won't build**: Ensure Qt5 development packages are installed

## Future OS Development

This system provides everything needed to develop a simple operating system:

1. **BIOS provides**: Console I/O, memory management primitives, program loader
2. **You can add**: File system, process scheduling, interrupt handlers
3. **Extend with**: More I/O devices, disk simulation, network simulation
4. **Test immediately**: No need for real hardware!

## License

Public domain / Unlicense. Do whatever you want with this code.
