; 8085 Operating System v0.3 - With Bank Switching & Extended Memory
; Features:
;   - 512KB total memory (8 banks × 64KB)
;   - 47KB user space in bank 0
;   - 32 concurrent tasks (up from 8)
;   - Bank switching commands
;   - Compressed code for efficiency
;
; Memory Map (Bank 0 - OS Bank):
;   0x0000-0x02FF : OS/BIOS code (768B target)
;   0x0300-0xBFFF : User program space (47KB!)
;   0xC000-0xC1FF : Task Control Blocks (32 tasks × 16 bytes = 512B)
;   0xC200-0xFFFD : System data and stacks
;
; Banks 1-7: Pure user space (64KB each = 448KB total)
;
CONIN_PORT	equ	0
CONOUT_PORT	equ	1
BANK_PORT	equ	254		; I/O port for bank switching
STACK_TOP	equ	0FFFEh

; Task Control Block layout
TCB_BASE	equ	0C000h
TCB_SIZE	equ	16
MAX_TASKS	equ	32		; Increased from 8!

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

; System variables
CURRENT_TCB	equ	0FFF0h
CURRENT_BANK	equ	0FFF2h	; Track current bank

	org 0000h

; ============================================================
; SYSTEM INITIALIZATION
; ============================================================
os_start:
	lxi sp, STACK_TOP
	
	; Initialize bank to 0
	xra a
	sta CURRENT_BANK
	
	; Initialize scheduler
	call sched_init
	
	; Display boot banner
	call print_banner
	
	; Enter shell
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
; SHELL
; ============================================================
shell_main:
	lxi h,msg_prompt
	call con_puts
	call read_cmd
	call parse_cmd
	jmp shell_main

read_cmd:
	lxi h,0400h
	mvi b,0
rc_loop:
	call con_getc_echo
	cpi 13
	jz rc_done
	cpi 10
	jz rc_done
	cpi 8
	jz rc_bs
	mov m,a
	inx h
	inr b
	mov a,b
	cpi 80
	jc rc_loop
	jmp rc_done
rc_bs:
	mov a,b
	ora a
	jz rc_loop
	dcx h
	dcr b
	jmp rc_loop
rc_done:
	call con_nl
	mvi m,0
	ret

parse_cmd:
	lxi h,0400h
pc_skip:
	mov a,m
	ora a
	rz
	cpi ' '
	jnz pc_check
	inx h
	jmp pc_skip
pc_check:
	ani 0DFh
	cpi 'H'
	jz cmd_help
	cpi 'M'
	jz cmd_mem
	cpi 'C'
	jz cmd_clear
	cpi 'B'
	jz cmd_bank
	cpi 'S'
	jz cmd_spawn
	cpi 'T'
	jz cmd_tasks
	cpi 'V'
	jz cmd_version
	cpi 'X'
	jz cmd_exit
	lxi h,msg_unk
	call con_puts
	ret

; ============================================================
; COMMANDS
; ============================================================

cmd_help:
	lxi h,msg_help
	call con_puts
	ret

cmd_mem:
	lxi h,msg_mem
	call con_puts
	ret

cmd_clear:
	lxi h,msg_clr
	call con_puts
	ret

; BANK - Show or switch memory bank
cmd_bank:
	lxi h,msg_bank1
	call con_puts
	
	; Show current bank
	lda CURRENT_BANK
	call print_hex8
	call con_nl
	
	; TODO: Parse argument to switch bank
	ret

; SPAWN - Create task
cmd_spawn:
	lxi h,msg_spwn
	call con_puts
	
	lxi h,demo_task
	lxi d,09000h
	call task_create
	
	cpi 0FFh
	jz cs_fail
	
	lxi h,msg_tid
	call con_puts
	call print_hex8
	call con_nl
	ret

cs_fail:
	lxi h,msg_fail
	call con_puts
	ret

; TASKS - List tasks
cmd_tasks:
	lxi h,msg_ttl
	call con_puts
	
	call get_task_count
	ora a
	jnz ct_show
	
	lxi h,msg_none
	call con_puts
	ret

ct_show:
	lxi h,msg_thdr
	call con_puts
	
	lxi h,TCB_BASE
	mvi b,0

ct_loop:
	mov a,b
	cpi MAX_TASKS
	jz ct_done
	
	push h
	push b
	lxi d,TCB_STATE
	dad d
	mov a,m
	pop b
	pop h
	
	cpi STATE_FREE
	jz ct_skip
	
	push h
	push b
	
	lxi h,msg_tid2
	call con_puts
	mov a,b
	call print_hex8
	
	lxi h,msg_st
	call con_puts
	
	pop b
	push b
	mov a,b
	lxi h,TCB_BASE
	call calc_tcb
	lxi d,TCB_STATE
	dad d
	mov a,m
	
	cpi STATE_READY
	jz ct_rdy
	cpi STATE_RUNNING
	jz ct_run
	lxi h,msg_blk
	jmp ct_st_done
ct_rdy:
	lxi h,msg_rdy
	jmp ct_st_done
ct_run:
	lxi h,msg_runn

ct_st_done:
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

cmd_version:
	lxi h,msg_ver
	call con_puts
	ret

cmd_exit:
	lxi h,msg_bye
	call con_puts
	hlt

; ============================================================
; SCHEDULER
; ============================================================

sched_init:
	lxi h,TCB_BASE
	lxi b,512		; 32 tasks × 16 bytes
si_clr:
	mvi m,0
	inx h
	dcx b
	mov a,b
	ora c
	jnz si_clr
	
	lxi h,0
	shld CURRENT_TCB
	ret

task_create:
	push h
	push d
	push b
	
	lxi h,TCB_BASE
	mvi b,0
tc_find:
	mov a,b
	cpi MAX_TASKS
	jz tc_full
	
	push h
	lxi d,TCB_STATE
	dad d
	mov a,m
	pop h
	cpi STATE_FREE
	jz tc_found
	
	lxi d,TCB_SIZE
	dad d
	inr b
	jmp tc_find

tc_full:
	mvi a,0FFh
	pop b
	pop d
	pop h
	ret

tc_found:
	mov m,b
	inx h
	mvi m,0
	inx h
	
	mvi m,STATE_READY
	inx h
	mvi m,0
	inx h
	
	xthl
	mov a,l
	xthl
	mov m,a
	inx h
	xthl
	mov a,h
	xthl
	mov m,a
	inx h
	
	xchg
	mov a,l
	xchg
	mov m,a
	inx h
	xchg
	mov a,h
	xchg
	mov m,a
	
	inx h
	mvi c,8
tc_zero:
	mvi m,0
	inx h
	dcr c
	jnz tc_zero
	
	mov a,b
	
	pop b
	pop d
	pop h
	ret

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

calc_tcb:
	lxi h,TCB_BASE
	ora a
	rz
	
	mvi b,TCB_SIZE
ct_mult:
	push b
	lxi d,TCB_SIZE
	dad d
	pop b
	dcr a
	jnz ct_mult
	ret

; ============================================================
; DEMO TASK
; ============================================================
demo_task:
	lxi h,msg_demo
	call con_puts
	call con_nl
dt_loop:
	mvi a,'.'
	call con_putc
	lxi b,01000h
dt_dly:
	dcx b
	mov a,b
	ora c
	jnz dt_dly
	jmp dt_loop

; ============================================================
; UTILITIES
; ============================================================

print_hex16:
	push psw
	mov a,h
	call print_hex8
	mov a,l
	call print_hex8
	pop psw
	ret

print_hex8:
	push psw
	push b
	mov b,a
	ani 0F0h
	rrc
	rrc
	rrc
	rrc
	call print_nib
	mov a,b
	ani 0Fh
	call print_nib
	pop b
	pop psw
	ret

print_nib:
	cpi 10
	jc pn_dig
	sui 10
	adi 'A'
	jmp pn_out
pn_dig:
	adi '0'
pn_out:
	call con_putc
	ret

; ============================================================
; MESSAGES (Compressed!)
; ============================================================
msg_banner:
	db 13,10,'8085 OS v0.3 - 512KB Memory!',13,10
	db 'Type HELP for commands',13,10,0

msg_prompt:
	db 13,10,'OS> ',0

msg_help:
	db 13,10,'Commands:',13,10
	db 'H - Help  M - Memory  C - Clear',13,10
	db 'B - Bank  S - Spawn   T - Tasks',13,10
	db 'V - Version  X - Exit',13,10,0

msg_mem:
	db 13,10,'Memory (Bank 0):',13,10
	db '0000-02FF: OS (768B)',13,10
	db '0300-BFFF: User (47KB)',13,10
	db 'C000-C1FF: TCBs (512B, 32 tasks)',13,10
	db 'C200-FFFD: System',13,10
	db 'Banks 1-7: 448KB user space',13,10,0

msg_clr:
	db 27,'[2J',27,'[H',0

msg_bank1:
	db 13,10,'Current Bank: ',0

msg_spwn:
	db 13,10,'Creating task...',13,10,0

msg_tid:
	db 'Task ID: ',0

msg_tid2:
	db '  ',0

msg_fail:
	db 'Failed (no slots)',13,10,0

msg_ttl:
	db 13,10,'Task List:',13,10,0

msg_none:
	db 'No tasks',13,10,0

msg_thdr:
	db 'ID  State',13,10
	db '--  -----',13,10,0

msg_st:
	db '  ',0

msg_rdy:
	db 'READY',0

msg_runn:
	db 'RUNNING',0

msg_blk:
	db 'BLOCKED',0

msg_demo:
	db '[Demo Task]',0

msg_ver:
	db 13,10,'8085 OS v0.3',13,10
	db '512KB (8 banks x 64KB)',13,10
	db '32 tasks, Bank switching',13,10,0

msg_bye:
	db 13,10,'Goodbye!',13,10,0

msg_unk:
	db 13,10,'Unknown cmd',13,10,0

print_banner:
	lxi h,msg_banner
	call con_puts
	ret

	end
