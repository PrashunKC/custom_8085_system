; 8085 Operating System - Phase A+C: Shell with Multitasking
; Integrated shell and cooperative multitasking scheduler
;
; Memory Map:
;   0x0000-0x03FF : OS/BIOS code (1KB)
;   0x0400-0x7FFF : User program space
;   0x8000-0x807F : Task Control Blocks (8 tasks × 16 bytes = 128 bytes)
;   0x8080-0xFFFF : System data and stacks
;
CONIN_PORT	equ	0
CONOUT_PORT	equ	1
STACK_TOP	equ	0FFFEh

; Task Control Block (TCB) layout
TCB_BASE	equ	8000h
TCB_SIZE	equ	16
MAX_TASKS	equ	8

TCB_ID		equ	0
TCB_STATE	equ	2
TCB_PC		equ	4
TCB_SP		equ	6
TCB_A		equ	8
TCB_BC		equ	10
TCB_DE		equ	12
TCB_HL		equ	14

; Task states
STATE_FREE	equ	0
STATE_READY	equ	1
STATE_RUNNING	equ	2
STATE_BLOCKED	equ	3

; System variables (high memory)
CURRENT_TCB	equ	0FFF0h	; Current task's TCB address
NEXT_TASK_ID	equ	0FFF2h	; Next task ID to assign

	org 0000h

; ============================================================
; SYSTEM INITIALIZATION
; ============================================================
os_start:
	lxi sp, STACK_TOP
	
	; Initialize scheduler
	call sched_init
	
	; Display boot banner
	call print_banner
	call print_welcome
	
	; Enter shell main loop
	jmp shell_main

; ============================================================
; CONSOLE I/O
; ============================================================
con_putc:
	out CONOUT_PORT
	ret

con_nl:
	mvi a,13
	call con_putc
	mvi a,10
	call con_putc
	ret

con_getc:
	in CONIN_PORT
	ora a
	jz con_getc
	ret

con_getc_echo:
	call con_getc
	push psw
	call con_putc
	pop psw
	ret

con_puts:
	mov a,m
	ora a
	rz
	call con_putc
	inx h
	jmp con_puts

; ============================================================
; SHELL - Main Loop
; ============================================================
shell_main:
	call print_prompt
	call read_command_line
	call parse_and_execute
	jmp shell_main

print_prompt:
	lxi h,msg_prompt
	call con_puts
	ret

; Read a command line into buffer at 0x0400
read_command_line:
	lxi h,0400h		; Command buffer
	mvi b,0			; Character count
rcl_loop:
	call con_getc_echo
	cpi 13			; Enter?
	jz rcl_done
	cpi 10			; LF?
	jz rcl_done
	cpi 8			; Backspace?
	jz rcl_backspace
	cpi 127			; Delete?
	jz rcl_backspace
	
	; Store character
	mov m,a
	inx h
	inr b
	mov a,b
	cpi 80			; Max 80 chars
	jc rcl_loop
	jmp rcl_done

rcl_backspace:
	mov a,b			; Check if buffer empty
	ora a
	jz rcl_loop
	dcx h			; Move back
	dcr b
	jmp rcl_loop

rcl_done:
	call con_nl
	mvi m,0			; Null terminate
	ret

; ============================================================
; COMMAND PARSER AND DISPATCHER
; ============================================================
parse_and_execute:
	lxi h,0400h		; Command buffer
	
	; Skip leading spaces
pae_skip_space:
	mov a,m
	ora a
	rz			; Empty line
	cpi ' '
	jnz pae_check_cmd
	inx h
	jmp pae_skip_space

pae_check_cmd:
	; Convert first char to uppercase
	mov a,m
	ani 0DFh		; Uppercase
	
	; Check for commands
	cpi 'H'
	jz cmd_help
	cpi 'M'
	jz cmd_mem
	cpi 'C'
	jz cmd_clear
	cpi 'S'
	jz cmd_spawn
	cpi 'T'
	jz cmd_tasks
	cpi 'K'
	jz cmd_kill
	cpi 'V'
	jz cmd_version
	cpi 'X'
	jz cmd_exit
	
	; Unknown command
	lxi h,msg_unknown
	call con_puts
	ret

; ============================================================
; COMMANDS
; ============================================================

; HELP - Show available commands
cmd_help:
	lxi h,msg_help
	call con_puts
	ret

; MEM - Show memory map
cmd_mem:
	lxi h,msg_mem_title
	call con_puts
	
	lxi h,msg_mem_os
	call con_puts
	
	lxi h,msg_mem_user
	call con_puts
	
	lxi h,msg_mem_tcb
	call con_puts
	
	lxi h,msg_mem_sys
	call con_puts
	
	ret

; CLEAR - Clear screen
cmd_clear:
	lxi h,msg_clear
	call con_puts
	ret

; SPAWN - Create a demo task
cmd_spawn:
	lxi h,msg_spawning
	call con_puts
	
	; Create a demo task
	lxi h,demo_task1	; Entry point
	lxi d,09000h		; Stack for task 1
	call task_create
	
	; Check if successful
	cpi 0FFh
	jz cs_failed
	
	; Success - show task ID
	lxi h,msg_task_created
	call con_puts
	call print_hex8
	call con_nl
	ret

cs_failed:
	lxi h,msg_spawn_failed
	call con_puts
	ret

; TASKS - Show task list
cmd_tasks:
	lxi h,msg_tasks_title
	call con_puts
	
	call get_task_count
	ora a
	jnz ct_show_tasks
	
	; No tasks
	lxi h,msg_no_tasks
	call con_puts
	ret

ct_show_tasks:
	; Print header
	lxi h,msg_task_header
	call con_puts
	
	; Iterate through TCBs
	lxi h,TCB_BASE
	mvi b,0			; Task counter

ct_loop:
	mov a,b
	cpi MAX_TASKS
	jz ct_done
	
	; Check if task is not free
	push h
	push b
	lxi d,TCB_STATE
	dad d
	mov a,m		; Get state
	pop b
	pop h
	
	cpi STATE_FREE
	jz ct_skip
	
	; Print task info
	push h
	push b
	
	; Task ID
	lxi h,msg_task_id_pre
	call con_puts
	mov a,b
	call print_hex8
	
	; Get state
	pop b
	push b
	mov a,b
	lxi h,TCB_BASE
	call calc_tcb_addr
	lxi d,TCB_STATE
	dad d
	mov a,m
	
	; Print state
	lxi h,msg_state_pre
	call con_puts
	cpi STATE_READY
	jz ct_state_ready
	cpi STATE_RUNNING
	jz ct_state_running
	cpi STATE_BLOCKED
	jz ct_state_blocked
	
	lxi h,msg_state_unknown
	jmp ct_state_done

ct_state_ready:
	lxi h,msg_state_ready
	jmp ct_state_done
ct_state_running:
	lxi h,msg_state_running
	jmp ct_state_done
ct_state_blocked:
	lxi h,msg_state_blocked

ct_state_done:
	call con_puts
	call con_nl
	
	pop b
	pop h

ct_skip:
	lxi d,TCB_SIZE
	dad d
	inr b
	jmp ct_loop

ct_done:
	ret

; KILL - Terminate a task (stub)
cmd_kill:
	lxi h,msg_not_impl
	call con_puts
	ret

; VERSION - Show OS version
cmd_version:
	lxi h,msg_version
	call con_puts
	ret

; EXIT - Halt system
cmd_exit:
	lxi h,msg_goodbye
	call con_puts
	hlt

; ============================================================
; SCHEDULER FUNCTIONS
; ============================================================

; Initialize scheduler
sched_init:
	; Clear all TCBs
	lxi h,TCB_BASE
	lxi b,128		; 8 tasks * 16 bytes
si_clear_loop:
	mvi m,0
	inx h
	dcx b
	mov a,b
	ora c
	jnz si_clear_loop
	
	; No current task
	lxi h,0
	shld CURRENT_TCB
	
	; Next task ID = 0
	xra a
	sta NEXT_TASK_ID
	
	ret

; Create task
; Input: HL = entry point, DE = stack pointer
; Output: A = task ID (0xFF if failed)
task_create:
	push h
	push d
	push b
	
	; Find free TCB
	lxi h,TCB_BASE
	mvi b,0
tc_find_free:
	mov a,b
	cpi MAX_TASKS
	jz tc_no_space
	
	; Check if this TCB is free
	push h
	lxi d,TCB_STATE
	dad d
	mov a,m
	pop h
	cpi STATE_FREE
	jz tc_found_free
	
	; Next TCB
	lxi d,TCB_SIZE
	dad d
	inr b
	jmp tc_find_free

tc_no_space:
	mvi a,0FFh
	pop b
	pop d
	pop h
	ret

tc_found_free:
	; Store task ID
	mov m,b
	inx h
	mvi m,0
	inx h
	
	; Set state = READY
	mvi m,STATE_READY
	inx h
	mvi m,0
	inx h
	
	; Set PC (entry point - from original HL)
	xthl			; Get entry point
	mov a,l
	xthl
	mov m,a
	inx h
	xthl
	mov a,h
	xthl
	mov m,a
	inx h
	
	; Set SP (from original DE)
	xchg			; HL = stack pointer
	mov a,l
	xchg
	mov m,a
	inx h
	xchg
	mov a,h
	xchg
	mov m,a
	
	; Initialize registers to zero
	inx h
	mvi c,8
tc_zero_regs:
	mvi m,0
	inx h
	dcr c
	jnz tc_zero_regs
	
	; Return task ID
	mov a,b
	
	pop b
	pop d
	pop h
	ret

; Get task count
get_task_count:
	lxi h,TCB_BASE
	mvi b,0
	mvi c,0

gtc_loop:
	mov a,b
	cpi MAX_TASKS
	jz gtc_done
	
	push h
	lxi d,TCB_STATE
	dad d
	mov a,m
	pop h
	
	cpi STATE_FREE
	jz gtc_skip
	inr c

gtc_skip:
	lxi d,TCB_SIZE
	dad d
	inr b
	jmp gtc_loop

gtc_done:
	mov a,c
	ret

; Calculate TCB address from task ID
; Input: A = task ID
; Output: HL = TCB address
calc_tcb_addr:
	lxi h,TCB_BASE
	ora a
	rz
	
	mvi b,TCB_SIZE
cta_loop:
	push b
	lxi d,TCB_SIZE
	dad d
	pop b
	dcr a
	jnz cta_loop
	ret

; ============================================================
; DEMO TASKS
; ============================================================

; Demo task 1 - prints message and yields
demo_task1:
	lxi h,msg_demo1
	call con_puts
	call con_nl
	
	; Loop forever
dt1_loop:
	mvi a,'.'
	call con_putc
	
	; Simple delay
	lxi b,01000h
dt1_delay:
	dcx b
	mov a,b
	ora c
	jnz dt1_delay
	
	jmp dt1_loop

; ============================================================
; UTILITY FUNCTIONS
; ============================================================

; Print 16-bit value in HL as hex
print_hex16:
	push psw
	mov a,h
	call print_hex8
	mov a,l
	call print_hex8
	pop psw
	ret

; Print 8-bit value in A as hex
print_hex8:
	push psw
	push b
	mov b,a
	
	; High nibble
	ani 0F0h
	rrc
	rrc
	rrc
	rrc
	call print_hex_nibble
	
	; Low nibble
	mov a,b
	ani 0Fh
	call print_hex_nibble
	
	pop b
	pop psw
	ret

print_hex_nibble:
	cpi 10
	jc phn_digit
	sui 10
	adi 'A'
	jmp phn_out
phn_digit:
	adi '0'
phn_out:
	call con_putc
	ret

; ============================================================
; MESSAGES
; ============================================================
msg_banner:
	db 13,10,'===========================================',13,10
	db '   8085 Operating System v0.2',13,10
	db '   Shell + Multitasking Support',13,10
	db '===========================================',13,10,0

msg_welcome:
	db 13,10,'Type HELP for available commands',13,10,0

msg_prompt:
	db 13,10,'OS> ',0

msg_help:
	db 13,10,'Available Commands:',13,10
	db '  HELP      - Show this help',13,10
	db '  MEM       - Display memory map',13,10
	db '  CLEAR     - Clear screen',13,10
	db '  SPAWN     - Create a demo task',13,10
	db '  TASKS     - List running tasks',13,10
	db '  KILL id   - Terminate task (not impl)',13,10
	db '  VERSION   - Show OS version',13,10
	db '  EXIT      - Halt system',13,10,0

msg_mem_title:
	db 13,10,'Memory Map:',13,10,0

msg_mem_os:
	db '  0000-03FF : OS/BIOS (1KB)',13,10,0

msg_mem_user:
	db '  0400-7FFF : User Programs (31KB)',13,10,0

msg_mem_tcb:
	db '  8000-807F : Task Control Blocks (128B)',13,10,0

msg_mem_sys:
	db '  8080-FFFD : System Data & Stacks',13,10,0

msg_clear:
	db 27,'[2J',27,'[H',0

msg_tasks_title:
	db 13,10,'Task List:',13,10,0

msg_no_tasks:
	db '  No tasks running',13,10,0

msg_task_header:
	db '  ID   State',13,10
	db '  --   -----',13,10,0

msg_task_id_pre:
	db '  ',0

msg_state_pre:
	db '    ',0

msg_state_ready:
	db 'READY',0

msg_state_running:
	db 'RUNNING',0

msg_state_blocked:
	db 'BLOCKED',0

msg_state_unknown:
	db 'UNKNOWN',0

msg_spawning:
	db 13,10,'Creating demo task...',13,10,0

msg_task_created:
	db 'Task created with ID: ',0

msg_spawn_failed:
	db 'Failed to create task (no free slots)',13,10,0

msg_demo1:
	db '[Demo Task 1] Hello from task!',0

msg_version:
	db 13,10,'8085 OS Version 0.2 Alpha',13,10
	db 'Built: 2025-10-15',13,10
	db 'Features: Shell, Multitasking',13,10,0

msg_goodbye:
	db 13,10,'System halted. Goodbye!',13,10,0

msg_unknown:
	db 13,10,'Unknown command. Type HELP for list.',13,10,0

msg_not_impl:
	db 13,10,'Not implemented yet.',13,10,0

print_banner:
	lxi h,msg_banner
	call con_puts
	ret

print_welcome:
	lxi h,msg_welcome
	call con_puts
	ret

	end
