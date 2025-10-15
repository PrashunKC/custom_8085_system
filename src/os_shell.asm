; 8085 Operating System Shell - Phase A
; Extends the BIOS monitor with OS-like features
; Target: 8080/8085 instruction set
;
; Memory Map:
;   0x0000-0x03FF : OS/BIOS code (1KB)
;   0x0400-0x7FFF : User program space
;   0x8000-0xFFFF : System data and stack
;
CONIN_PORT	equ	0
CONOUT_PORT	equ	1
STACK_TOP	equ	0FFFEh

; System variables (high memory)
CURRENT_TASK	equ	0FFF0h	; Current task ID
TASK_COUNT	equ	0FFF1h	; Number of tasks
SYS_FLAGS	equ	0FFF2h	; System flags

	org 0000h

; ============================================================
; SYSTEM INITIALIZATION
; ============================================================
os_start:
	lxi sp, STACK_TOP
	
	; Initialize system variables
	xra a
	sta CURRENT_TASK
	sta TASK_COUNT
	sta SYS_FLAGS
	
	; Display boot banner
	call print_banner
	call print_welcome
	
	; Enter shell main loop
	jmp shell_main

; ============================================================
; CONSOLE I/O (from BIOS)
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
	cpi 'R'
	jz cmd_run
	cpi 'T'
	jz cmd_tasks
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
	
	; Show OS/BIOS area
	lxi h,msg_mem_os
	call con_puts
	
	; Show user program area
	lxi h,msg_mem_user
	call con_puts
	
	; Show system area
	lxi h,msg_mem_sys
	call con_puts
	
	; Show free memory
	lxi h,msg_mem_free
	call con_puts
	lxi h,07C00h		; Calculate free (32000 bytes as example)
	call print_hex16
	lxi h,msg_bytes
	call con_puts
	call con_nl
	
	ret

; CLEAR - Clear screen (send ANSI escape)
cmd_clear:
	lxi h,msg_clear
	call con_puts
	ret

; RUN <addr> - Execute program at address
cmd_run:
	; TODO: Parse address and jump to it
	lxi h,msg_not_impl
	call con_puts
	ret

; TASKS - Show task list
cmd_tasks:
	lxi h,msg_tasks_title
	call con_puts
	
	lda TASK_COUNT
	ora a
	jnz ct_show_tasks
	
	; No tasks
	lxi h,msg_no_tasks
	call con_puts
	ret

ct_show_tasks:
	; TODO: Implement task list display
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
	db '   8085 Operating System v0.1',13,10
	db '   Simple Shell with Task Support',13,10
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
	db '  RUN addr  - Execute program at address',13,10
	db '  TASKS     - List running tasks',13,10
	db '  VERSION   - Show OS version',13,10
	db '  EXIT      - Halt system',13,10
	db 13,10,'Legacy BIOS commands:',13,10
	db '  D a n     - Dump memory',13,10
	db '  M a       - Modify memory',13,10
	db '  G a       - Go to address',13,10
	db '  L         - Load Intel HEX',13,10,0

msg_mem_title:
	db 13,10,'Memory Map:',13,10,0

msg_mem_os:
	db '  0000-03FF : OS/BIOS (1KB)',13,10,0

msg_mem_user:
	db '  0400-7FFF : User Programs (31KB)',13,10,0

msg_mem_sys:
	db '  8000-FFFD : System Data (32KB)',13,10,0

msg_mem_free:
	db '  Free Memory: ',0

msg_bytes:
	db ' bytes',0

msg_clear:
	db 27,'[2J',27,'[H',0	; ANSI clear screen + home

msg_tasks_title:
	db 13,10,'Task List:',13,10,0

msg_no_tasks:
	db '  No tasks running',13,10,0

msg_version:
	db 13,10,'8085 OS Version 0.1 Alpha',13,10
	db 'Built: 2025-10-15',13,10
	db 'Features: Shell, Memory Management (planned)',13,10,0

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
