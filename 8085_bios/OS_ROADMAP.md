# 8085 Operating System Development Roadmap

## Current Status: Phase A Complete ✅

### Phase A: Simple OS Shell ✅ DONE
**Location:** `/home/kde/Documents/8085_bios/src/os_shell.asm`

**What we built:**
- Command-line shell with prompt `OS>`
- Command parser and dispatcher
- Built-in commands:
  - `HELP` - Show available commands
  - `MEM` - Display memory map
  - `CLEAR` - Clear screen (ANSI escape codes)
  - `RUN addr` - Execute program at address (stub)
  - `TASKS` - List running tasks (stub)
  - `VERSION` - Show OS version
  - `EXIT` - Halt system
- Memory organization:
  - `0x0000-0x03FF` : OS/BIOS code (1KB)
  - `0x0400-0x7FFF` : User program space (31KB)
  - `0x8000-0xFFFF` : System data (32KB)

**Testing:**
```bash
cd /home/kde/Documents/8085_bios
python3 tools/assemble.py src/os_shell.asm build/bios.bin
./8085_bios_system
```

**Commands to try:**
- Type `HELP`
- Type `MEM` to see memory layout
- Type `VERSION`
- Type `CLEAR` to clear screen

---

## Phase C: Cooperative Multitasking Scheduler 🚧 IN PROGRESS
**Location:** `/home/kde/Documents/8085_bios/src/scheduler.asm`

**What we're building:**
- Task Control Block (TCB) structure (16 bytes per task)
- Support for up to 8 concurrent tasks
- Round-robin scheduling
- Voluntary task yielding
- Task states: FREE, READY, RUNNING, BLOCKED

**TCB Structure:**
```
Offset  Size  Description
------  ----  -----------
0-1     2     Task ID
2-3     2     State (0=free, 1=ready, 2=running, 3=blocked)
4-5     2     PC (Program Counter) - saved on yield
6-7     2     SP (Stack Pointer) - saved on yield
8-9     2     A register
10-11   2     BC registers
12-13   2     DE registers
14-15   2     HL registers
```

**Scheduler Functions:**
- `sched_init` - Initialize scheduler
- `task_create` - Create new task with entry point and stack
- `task_yield` - Voluntary context switch
- `task_terminate` - End current task
- `get_task_count` - Count active tasks
- `print_task_list` - Debug task list

**Next Steps for Phase C:**
1. Integrate scheduler with OS shell
2. Add system calls for task management
3. Create demo tasks
4. Test task switching

---

## Phase B: Separate OS Kernel 📋 PLANNED

**Goals:**
- Clean separation between BIOS and OS kernel
- System call interface (INT-based or CALL-based)
- Memory protection (logical)
- Process isolation

**Memory Layout:**
```
0x0000-0x00FF : BIOS interrupt vectors
0x0100-0x03FF : BIOS code
0x0400-0x0FFF : OS Kernel (3KB)
0x1000-0x7FFF : User programs (28KB)
0x8000-0xEFFF : Heap/Data (28KB)
0xF000-0xFFFF : Stack and system (4KB)
```

**System Calls to Implement:**
```
SYS_READ   = 1  ; Read from device
SYS_WRITE  = 2  ; Write to device
SYS_OPEN   = 3  ; Open file/device
SYS_CLOSE  = 4  ; Close file/device
SYS_EXEC   = 5  ; Execute program
SYS_EXIT   = 6  ; Terminate process
SYS_FORK   = 7  ; Create child process (simplified)
SYS_WAIT   = 8  ; Wait for event
SYS_GETPID = 9  ; Get process ID
SYS_SLEEP  = 10 ; Sleep milliseconds
```

**Implementation:**
- System call interface via RST instructions
- Kernel mode vs User mode (logical flag)
- Simple process table
- Inter-process communication (IPC)

---

## Phase D: Advanced Features 🎯 FUTURE

### D1: Simple Filesystem
- In-memory filesystem
- File operations: create, read, write, delete
- Directory structure
- File descriptors

### D2: Device Drivers
- Console driver (abstraction)
- Timer driver (for scheduling)
- Storage driver (simulated disk)

### D3: Advanced Scheduling
- Priority-based scheduling
- Preemptive multitasking (timer interrupts)
- Wait queues
- Semaphores/mutexes

### D4: Memory Management
- Dynamic memory allocation
- Heap manager
- Memory pools
- Garbage collection (optional)

### D5: Shell Enhancements
- Command history
- Tab completion
- Piping (|)
- Redirection (>, <)
- Background jobs (&)
- Job control

### D6: Networking (Simulated)
- Socket interface
- TCP/IP stack (simplified)
- Network commands (ping, telnet, etc.)

---

## Development Tools

### Assembler
**Location:** `/home/kde/Documents/8085_bios/tools/assemble.py`
- Custom Python-based 8080/8085 assembler
- Supports full instruction set
- Two-pass assembly
- Label resolution

### Emulator
**Location:** `/home/kde/Documents/8085_bios/8085_bios_system`
- C++ implementation with Qt5 GUI
- Interactive terminal
- Step/Run modes
- Register and memory display
- I/O port callbacks

### Build System
**Location:** `/home/kde/Documents/8085_bios/Makefile`
```bash
make clean  # Clean build artifacts
make        # Build emulator and assemble BIOS
```

---

## Testing Strategy

### Unit Tests
- Test individual scheduler functions
- Test system calls
- Test memory management

### Integration Tests
- Multiple tasks running simultaneously
- Task communication
- Resource sharing

### System Tests
- Complete OS boot sequence
- User programs execution
- Shell command interaction

---

## Example Programs to Write

### 1. Hello World Task
```assembly
task_hello:
    lxi h,msg_hello
    call sys_print
    call task_yield
    jmp task_hello
msg_hello: db 'Hello from Task!',13,10,0
```

### 2. Counter Task
```assembly
task_counter:
    lxi h,0
counter_loop:
    inx h
    call print_hex16
    call task_yield
    jmp counter_loop
```

### 3. Producer-Consumer
```assembly
; Producer task
producer:
    call generate_data
    call put_in_queue
    call task_yield
    jmp producer

; Consumer task
consumer:
    call get_from_queue
    call process_data
    call task_yield
    jmp consumer
```

---

## Resources

### Documentation
- 8085 Instruction Set Reference
- 8080 Assembly Language Guide
- Operating System Concepts (Tanenbaum)

### Similar Projects
- CP/M Operating System
- RT-11 (DEC)
- Fuzix (Z80 Unix-like OS)

---

## Next Immediate Steps

1. **Integrate Phase C Scheduler:**
   - Merge `scheduler.asm` into `os_shell.asm`
   - Add `TASKS` command implementation
   - Create `SPAWN` command to create test tasks

2. **Test Task Switching:**
   - Create 2 simple tasks
   - Verify context switching works
   - Verify task list displays correctly

3. **Add System Call Interface:**
   - Design system call mechanism
   - Implement basic syscalls (print, yield, exit)
   - Update tasks to use syscalls

4. **Move to Phase B:**
   - Separate BIOS and kernel
   - Implement syscall dispatcher
   - Create user/kernel mode separation

---

## Build and Run

### Current Phase A:
```bash
cd /home/kde/Documents/8085_bios
python3 tools/assemble.py src/os_shell.asm build/bios.bin
./8085_bios_system
```

### When Phase C is integrated:
```bash
cd /home/kde/Documents/8085_bios
python3 tools/assemble.py src/os_integrated.asm build/bios.bin
./8085_bios_system
```

---

**Last Updated:** October 15, 2025  
**Version:** 0.1 Alpha  
**Status:** Phase A Complete, Phase C In Progress
