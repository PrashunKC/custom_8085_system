# 8085 OS Project - Quick Start Guide

## What You Have Now ✅

### **Phase A Complete: OS Shell**
Your 8085 now has a working operating system shell!

**File:** `src/os_shell.asm` (1336 bytes)

**Features:**
- ✅ Command-line interface with `OS>` prompt
- ✅ Command parser
- ✅ Memory management display
- ✅ System information
- ✅ Clean architecture ready for expansion

**Try it now:**
```bash
cd /home/kde/Documents/8085_bios
./8085_bios_system
```

**Commands available:**
- `HELP` - Show all commands
- `MEM` - Display memory layout
- `VERSION` - OS version info
- `CLEAR` - Clear screen
- `EXIT` - Halt system

---

## What's Next: Phases C, B, D

### **Phase C: Task Scheduler** 🚧
**File:** `src/scheduler.asm` (ready to integrate)

Will add:
- Up to 8 concurrent tasks
- Round-robin scheduling
- Task creation and termination
- `TASKS` command to list running tasks
- `SPAWN` command to create tasks

### **Phase B: OS Kernel**
Will add:
- System call interface
- Kernel/user mode separation
- Process management
- Better memory protection

### **Phase D: Advanced Features**
- Filesystem
- Device drivers
- Priority scheduling
- Memory allocation
- Shell enhancements (history, pipes, etc.)

---

## Architecture

### Memory Map:
```
0x0000-0x03FF : OS/BIOS code (1KB)
0x0400-0x7FFF : User programs (31KB)
0x8000-0xFFFF : System data & stack (32KB)
```

### Task Control Blocks (Phase C):
```
Location: 0x8000
Size: 16 bytes per task
Max tasks: 8
```

---

## Next Steps to Continue

### Step 1: Test Phase A
```bash
# Run the OS
./8085_bios_system

# Try commands:
HELP
MEM
VERSION
```

### Step 2: Integrate Phase C (Task Scheduler)
I can help you:
1. Merge scheduler into OS shell
2. Add task creation commands
3. Create demo tasks
4. Test multitasking

### Step 3: Move to Phase B (OS Kernel)
Then we'll:
1. Separate BIOS and kernel
2. Add system calls
3. Implement process isolation

---

## Development Workflow

### Edit Assembly:
```bash
nano src/os_shell.asm  # or your preferred editor
```

### Assemble:
```bash
python3 tools/assemble.py src/os_shell.asm build/bios.bin
```

### Run:
```bash
./8085_bios_system
```

### Rebuild Emulator (if needed):
```bash
make clean && make
```

---

## Files Overview

```
8085_bios/
├── src/
│   ├── os_shell.asm      ✅ Phase A (Current)
│   ├── scheduler.asm     🚧 Phase C (Ready)
│   └── bios.asm          📦 Original BIOS
├── tools/
│   └── assemble.py       🔧 Assembler
├── build/
│   └── bios.bin          💾 Compiled binary
├── bios_gui.cpp          🖥️  GUI code
├── cpu8085.cpp/h         🔌 Emulator
├── Makefile              🛠️  Build system
├── OS_ROADMAP.md         📋 Full roadmap
└── 8085_bios_system      ▶️  Executable

```

---

## Want to Continue?

**Tell me what you'd like to do next:**

1. **Test more Phase A features** - Add more shell commands
2. **Integrate Phase C** - Add multitasking right now!
3. **Jump to Phase B** - Start building the kernel
4. **Write demo programs** - Create user programs to run
5. **Something else** - Your idea!

Just say the word! 🚀
