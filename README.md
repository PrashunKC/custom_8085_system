# 8085 BIOS System

This project combines a C++ Intel 8085 emulator with a Qt5 monitor GUI and a
small 8085 BIOS/monitor written in assembly. It is separate from
[`8085_emulation`](../8085_emulation/), which provides a simpler single-bank
CPU debugger without the BIOS terminal and banked-memory model.

## Architecture

The emulator models an 8-bit 8085 CPU with:

- 8 banks of 64 KiB memory (512 KiB total, one bank visible at a time).
- The standard registers and S/Z/AC/P/CY flags.
- 8085 instruction execution, stack operations, and reset behavior.
- `IN`/`OUT` callbacks used by the GUI to connect port 0 to terminal input and
  port 1 to terminal output.
- Binary loading at an arbitrary 16-bit address, with user programs defaulting
  to `0x2000`.

The Qt application in `bios_gui.cpp` provides BIOS loading, reset, step, run,
stop, program loading, register/flag display, memory inspection, and a
terminal widget. The BIOS monitor in `src/bios.asm` runs from `0x0000` and
offers `H`, `D`, `M`, `G`, and `L` commands.

## BIOS monitor contract

The GUI's callbacks implement the ports expected by the monitor:

| Port | Direction | Meaning |
| ---: | --- | --- |
| 0 | `IN` | Next terminal byte, or `0` when input is unavailable |
| 1 | `OUT` | Append one ASCII byte to the terminal |

The BIOS busy-waits on port 0 when it needs input. Change `CONIN_PORT` and
`CONOUT_PORT` in [`src/bios.asm`](src/bios.asm) and update the GUI callbacks
together if the device contract changes.

## Repository layout

| Path | Purpose |
| --- | --- |
| `cpu8085.h/.cpp` | CPU state, instruction dispatch, memory banks, and I/O callbacks |
| `bios_gui.cpp` | Qt5 terminal, debugger controls, and display panels |
| `src/bios.asm` | BIOS monitor source |
| `src/os_*.asm` | Experimental shell and multitasking OS variants |
| `src/scheduler.asm` | Standalone scheduler experiment |
| `tools/assemble.sh` | Assemble BIOS with Macroassembler AS and emit binary/HEX |
| `tools/assemble.py` | Small Python 8085 assembler for supported mnemonics |
| `test_minimal.asm` | Minimal assembly input for manual emulator tests |

The `8085_LIMITATIONS.md` document explains the 16-bit address-space limit and
why bank switching is used to expose more than 64 KiB over time.

## Building

### Assemble the BIOS directly

```bash
./tools/assemble.sh src/bios.asm
```

This requires `asl`, `p2bin`, and `p2hex` on `PATH` (or the `ASL`, `P2BIN`,
and `P2HEX` environment variables). Outputs are written to `build/`.

`tools/assemble.py` is an independent, intentionally limited assembler:

```bash
python3 tools/assemble.py test_minimal.asm build/test_minimal.bin
```

### Build the Qt application

```bash
cmake -S . -B build/cmake
cmake --build build/cmake
./build/cmake/8085_bios_system
```

Qt5 development packages and a C++17 compiler are required. The CMake file
declares a BIOS custom target, but the current repository has no root Makefile;
if that target cannot create `build/bios.bin`, assemble the BIOS first with
`tools/assemble.sh`.

## Running the monitor

1. Start the GUI.
2. Load or assemble `build/bios.bin`.
3. Click **Run** or **Step**.
4. At the `>` prompt, use:
   - `H` for help.
   - `D 2000 40` to dump 64 bytes.
   - `M 2100` to modify memory.
   - `G 1000` to jump to an address.
   - `L` to receive Intel HEX records.

The GUI's **Load Program** action loads a binary at `0x2000`; use `G 2000` in
the monitor to execute it.

## Limitations

- The emulator is an instructional model, not cycle-accurate hardware.
- The BIOS and GUI must agree on port semantics.
- The Python assembler supports only the instruction/directive subset encoded
  in its opcode table; Macroassembler AS remains the authoritative BIOS path.
- The experimental OS assembly files are not part of the default GUI build.

## License

See [`LICENSE`](LICENSE). The license text governs redistribution and use.
