# 8085 BIOS System - Quick Start Guide

## What Was Built

You now have a complete **8085 microprocessor system** with:

### 1. **Enhanced C++ Emulator** (`cpu8085.h/cpp`)
- Copied from your `8085_emulation` project
- Extended with **I/O port callbacks** for BIOS integration
- Supports IN/OUT instructions connected to GUI
- `loadBinary()` function to load ROM files

### 2. **Interactive Qt5 GUI** (`bios_gui.cpp`)
- **TerminalWidget**: Interactive console that captures keyboard input
- **Register Display**: Real-time view of all 8085 registers
- **Flags Display**: Monitor processor flags
- **Memory Viewer**: See first 256 bytes of RAM/ROM
- **Controls**: Load BIOS, Reset, Step, Run, Stop, Load Program

### 3. **BIOS Monitor** (`src/bios.asm`)
- Full-featured monitor ROM with interactive commands
- Console I/O via ports 0 (IN) and 1 (OUT)
- Commands: H (help), D (dump), M (modify), G (go), L (load HEX)
- Foundation for OS development

### 4. **Build System**
- Makefile with `quick` target for fast builds
- CMakeLists.txt for cmake users
- Automatically links Qt5

## What You Can Do Right Now

### 1. Run the System

The GUI is already running! You should see a window with:
- Left side: Interactive terminal and memory viewer
- Right side: Registers, flags, and control buttons

### 2. Load the Placeholder BIOS

Click **"Load BIOS"** button:
- It loads `build/bios.bin` (currently a simple "Hi" test program)
- Sets PC to 0x0000

### 3. Execute

Click **"Run"** or **"Step"**:
- The CPU will execute the program
- You should see "Hi" appear in the terminal!

### 4. Build the Real BIOS

To get the full monitor with commands:

**Option A: Install ASL assembler** (recommended)

```bash
# On Fedora
sudo dnf install asl

# Then rebuild BIOS
cd /home/kde/Documents/8085_bios
make clean
make

# The real bios.bin will be created
```

**Option B: Use a different assembler**

If you have another 8080/8085 assembler (like AS, z80asm, etc.), you can:
1. Assemble `src/bios.asm` manually
2. Place output in `build/bios.bin`
3. Reload in the GUI

## Next Steps

### Write Your First Program

Create `test_program.asm`:
```asm
; Simple program that counts 0-9 and outputs to console
        ORG 2000h
        MVI B, 30h      ; ASCII '0'
        MVI C, 0Ah      ; Count 10 times
loop:
        MOV A, B
        OUT 1           ; Output to console
        INR B
        DCR C
        JNZ loop
        HLT
```

Assemble it, then:
1. Click "Load Program..." in GUI
2. Select your binary
3. Type in terminal (when BIOS prompt appears): `G 2000`

### Extend the BIOS

Edit `src/bios.asm` to add:
- New commands (e.g., F for fill memory)
- Device drivers
- System calls
- Boot loader

### Create an Operating System

The BIOS provides:
- Memory management (D/M commands)
- Program loading (L command)
- Console I/O (ports 0/1)
- Execution control (G command)

You can build on this to create:
- File system
- Multi-tasking
- Shell/command interpreter
- Games!

## Architecture Overview

```
┌─────────────────────────────────────┐
│         Qt5 GUI (bios_gui.cpp)       │
│  ┌──────────────┐  ┌──────────────┐ │
│  │   Terminal   │  │   Registers  │ │
│  │   (I/O)      │  │   Memory     │ │
│  └──────┬───────┘  └──────────────┘ │
└─────────┼────────────────────────────┘
          │ I/O Callbacks
    ┌─────▼──────────────────────┐
    │  CPU8085 Emulator          │
    │  ┌──────────────────────┐  │
    │  │ Registers & Flags    │  │
    │  ├──────────────────────┤  │
    │  │ 64KB Memory          │  │
    │  │ 0x0000: BIOS ROM     │  │
    │  │ 0x2000+: User RAM    │  │
    │  ├──────────────────────┤  │
    │  │ I/O Ports            │  │
    │  │ Port 0: Console IN   │  │
    │  │ Port 1: Console OUT  │  │
    │  └──────────────────────┘  │
    └────────────────────────────┘
```

## Files Overview

```
/home/kde/Documents/8085_bios/
├── src/bios.asm           # BIOS monitor source (needs assembly)
├── cpu8085.h              # Enhanced emulator header
├── cpu8085.cpp            # Enhanced emulator implementation
├── bios_gui.cpp           # Qt5 GUI with interactive terminal
├── Makefile               # Build system
├── CMakeLists.txt         # Alternative CMake build
├── build/
│   └── bios.bin           # BIOS ROM (currently placeholder)
├── 8085_bios_system       # Executable (already running!)
└── README.md              # Full documentation
```

## Troubleshooting

**Q: GUI doesn't show my typing**
A: Click inside the terminal area to give it focus

**Q: Can't load BIOS**
A: Make sure `build/bios.bin` exists. Run `make` or create manually

**Q: BIOS assembler not found**
A: Install `asl` package or use the placeholder for now

**Q: Want to use code from original emulator**
A: The `cpu8085.cpp` here IS your original code, just extended with I/O callbacks!

## What's Different from Your Original Emulator?

### Added Features
1. **I/O Port Support**: IN/OUT instructions now work via callbacks
2. **Interactive Terminal**: Real keyboard input/output
3. **BIOS Integration**: ROM loaded at 0x0000
4. **loadBinary()**: Easy ROM/program loading
5. **Better for OS dev**: Foundation for building operating systems

### Same Features
- All 246 8085 opcodes
- Register display
- Flags display
- Memory viewer
- Step/Run/Stop controls
- Qt5 GUI

The core emulator (`cpu8085.cpp`) is almost identical to your original, just with the I/O enhancements!

## Resources

- **8085 Instruction Set**: See your original `INSTRUCTIONS.md`
- **BIOS Commands**: Type `H` in the BIOS prompt
- **Example Programs**: Create in `src/` directory
- **Intel HEX Format**: For the L (load) command

Happy hacking! You now have everything you need to develop 8085 programs and even a simple OS! 🚀
