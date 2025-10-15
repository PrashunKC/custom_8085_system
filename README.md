# Custom 8085 System

A complete Intel 8085 microprocessor emulation system with integrated BIOS/monitor ROM and interactive GUI. This project provides a fully functional development environment for learning 8085 programming, developing operating systems, or testing embedded software.

## Features

- **Complete 8085 Emulator** - Full instruction set implementation (246 valid opcodes)
- **Interactive BIOS Monitor** - Built-in monitor with commands for memory inspection, program loading, and execution
- **Qt5 GUI Interface** - Modern graphical interface with real-time terminal, register display, and memory viewer
- **I/O Port System** - Console I/O through emulated ports for interactive programs
- **Assembly Support** - Python-based assembler for building BIOS and custom programs
- **Development Ready** - Everything needed to develop and test 8085 programs or even a simple OS

## Project Structure

```
custom_8085_system/
├── 8085_bios/              # Main BIOS system
│   ├── src/                # BIOS assembly source code
│   ├── build/              # Build artifacts (binaries, hex files)
│   ├── tools/              # Assembly tools
│   ├── cpu8085.h/cpp       # 8085 emulator core
│   ├── bios_gui.cpp        # Qt5 GUI application
│   ├── Makefile            # Build configuration
│   └── README.md           # Detailed documentation
├── LICENSE                 # Project license
└── README.md               # This file
```

## Quick Start

### Prerequisites

- C++ compiler (g++ 7+ or clang++)
- Qt5 development libraries
- Python 3 (for assembler)
- Make

### Build

```bash
cd 8085_bios
make quick
```

This will:
1. Assemble the BIOS monitor from `src/bios.asm`
2. Compile the 8085 emulator with Qt5 GUI
3. Create the executable `8085_bios_system`

### Run

```bash
cd 8085_bios
./8085_bios_system
```

Or use:
```bash
make run
```

## Usage

1. Launch the emulator
2. Click "Load BIOS" to load the monitor ROM
3. Click "Run" to start execution
4. Type commands in the terminal (try `H` for help)

Available BIOS commands:
- `H` - Display help
- `D addr len` - Dump memory
- `M addr` - Modify memory
- `G addr` - Go to address and execute
- `L` - Load Intel HEX program
- `V` - Version info
- `X` - Exit/halt

## Documentation

For detailed information, see:
- [8085 BIOS System Documentation](8085_bios/README.md) - Complete reference
- [Quick Start Guide](8085_bios/QUICKSTART.md) - Getting started
- [Integration Details](8085_bios/INTEGRATION_COMPLETE.md) - System architecture
- [Build Success Notes](8085_bios/BUILD_SUCCESS.md) - Build system details

## Development

This system is ideal for:
- Learning 8085 assembly programming
- Developing and testing embedded software
- Creating a simple operating system
- Educational purposes and experimentation

The emulator provides immediate feedback without requiring physical hardware, making it perfect for rapid development and testing.

## License

See [LICENSE](LICENSE) file for details.
