; 8085 OS - Phase C: Cooperative Multitasking Scheduler
; Simple round-robin task scheduler with voluntary yielding
;
; Task Control Block (TCB) structure (16 bytes per task):
;   Offset 0-1:  Task ID (16-bit)
;   Offset 2-3:  Task State (0=free, 1=ready, 2=running, 3=blocked)
;   Offset 4-5:  PC (program counter) - saved when task yields
;   Offset 6-7:  SP (stack pointer) - saved when task yields
;   Offset 8-9:  A register
;   Offset 10-11: BC registers
;   Offset 12-13: DE registers
;   Offset 14-15: HL registers
;
; Maximum 8 tasks, TCB table at 0x8000

TCB_BASE	equ	8000h
TCB_SIZE	equ	16
MAX_TASKS	equ	8

; TCB offsets
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
CURRENT_TCB	equ	0FFF0h	; Pointer to current task's TCB

; ============================================================
; SCHEDULER INITIALIZATION
; ============================================================
sched_init:
	; Clear all TCBs
	lxi h,TCB_BASE
	lxi b,MAX_TASKS * TCB_SIZE
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
	
	ret

; ============================================================
; CREATE TASK
; Input: HL = entry point address
;        DE = stack pointer for task
; Output: A = task ID (0xFF if failed)
; ============================================================
task_create:
	push h
	push d
	push b
	
	; Find free TCB
	lxi h,TCB_BASE
	mvi b,0			; Task counter
tc_find_free:
	mov a,b
	cpi MAX_TASKS
	jz tc_no_space
	
	; Check if this TCB is free
	push h
	lxi d,TCB_STATE
	dad d
	mov a,m			; Get state
	pop h
	cpi STATE_FREE
	jz tc_found_free
	
	; Next TCB
	lxi d,TCB_SIZE
	dad d
	inr b
	jmp tc_find_free

tc_no_space:
	mvi a,0FFh		; Failed
	pop b
	pop d
	pop h
	ret

tc_found_free:
	; H:L now points to free TCB
	; B = task ID
	
	; Save TCB address
	push h
	
	; Set task ID
	mov m,b
	inx h
	mvi m,0
	inx h
	
	; Set state = READY
	mvi m,STATE_READY
	inx h
	mvi m,0
	inx h
	
	; Set PC (entry point from saved HL on stack)
	pop d			; Get TCB base back
	push d
	xthl			; Get original HL (entry point)
	pop d			; DE = entry point
	xthl			; Restore stack
	push h
	mov m,e			; PC low
	inx h
	mov m,d			; PC high
	inx h
	
	; Set SP (from saved DE on stack)
	pop h
	xthl			; Get original DE (stack pointer)
	pop h			; HL = stack pointer
	xthl			; Restore stack
	push h
	pop d			; DE = stack pointer
	pop h			; HL = TCB pointer
	push h
	
	mov m,e			; SP low
	inx h
	mov m,d			; SP high
	
	; Initialize registers (all zeros)
	inx h
	mvi m,0			; A
	inx h
	mvi m,0
	inx h
	mvi m,0			; BC
	inx h
	mvi m,0
	inx h
	mvi m,0			; DE
	inx h
	mvi m,0
	inx h
	mvi m,0			; HL
	inx h
	mvi m,0
	
	; Return task ID
	mov a,b
	
	pop h			; Clean stack
	pop b
	pop d
	pop h
	ret

; ============================================================
; TASK YIELD - Voluntary context switch
; Called by running task to give up CPU
; ============================================================
task_yield:
	; Save current task context if there is one
	lhld CURRENT_TCB
	mov a,h
	ora l
	jz ty_no_current	; No current task
	
	; Save registers to current TCB
	; HL already points to TCB
	push psw
	push h
	
	; Move to register save area
	lxi d,TCB_A
	dad d
	
	; Save A
	pop d			; Get H back
	push d
	pop psw			; Get A back
	push psw
	mov m,a
	inx h
	mvi m,0
	inx h
	
	; Save BC
	mov m,c
	inx h
	mov m,b
	inx h
	
	; Save DE
	mov m,e
	inx h
	mov m,d
	inx h
	
	; Save HL
	pop d			; Get saved HL
	mov m,e
	inx h
	mov m,d
	
	; Save SP and PC would require special handling
	; For now, skip (cooperative yield assumes task will resume from call point)
	
	pop psw

ty_no_current:
	; Find next ready task (round-robin)
	call find_next_ready_task
	
	; If A = 0xFF, no ready tasks, return to caller
	cpi 0FFh
	rz
	
	; Switch to new task
	; A = task ID
	call switch_to_task
	
	ret

; ============================================================
; FIND NEXT READY TASK
; Output: A = task ID (0xFF if none found)
; ============================================================
find_next_ready_task:
	; Start from task 0
	lxi h,TCB_BASE
	mvi b,0

fnrt_loop:
	mov a,b
	cpi MAX_TASKS
	jz fnrt_none_found
	
	; Check state
	push h
	lxi d,TCB_STATE
	dad d
	mov a,m
	pop h
	
	cpi STATE_READY
	jz fnrt_found
	
	; Next task
	lxi d,TCB_SIZE
	dad d
	inr b
	jmp fnrt_loop

fnrt_none_found:
	mvi a,0FFh
	ret

fnrt_found:
	mov a,b
	ret

; ============================================================
; SWITCH TO TASK
; Input: A = task ID
; ============================================================
switch_to_task:
	; Calculate TCB address
	mov b,a
	lxi h,TCB_BASE
	
	; Multiply task ID by TCB_SIZE
	mvi a,0
stt_mult:
	mov a,b
	ora a
	jz stt_mult_done
	lxi d,TCB_SIZE
	dad d
	dcr b
	jmp stt_mult

stt_mult_done:
	; HL = TCB address
	shld CURRENT_TCB
	
	; Set state to RUNNING
	push h
	lxi d,TCB_STATE
	dad d
	mvi m,STATE_RUNNING
	pop h
	
	; Restore registers from TCB
	lxi d,TCB_A
	dad d
	
	; Restore A
	mov a,m
	push psw
	inx h
	inx h
	
	; Restore BC
	mov c,m
	inx h
	mov b,m
	inx h
	
	; Restore DE
	mov e,m
	inx h
	mov d,m
	inx h
	
	; Restore HL
	mov a,m
	inx h
	mov h,m
	mov l,a
	
	pop psw
	
	; Would restore PC/SP here for full context switch
	; For now, return (cooperative multitasking)
	
	ret

; ============================================================
; TASK TERMINATE
; Marks current task as FREE and yields
; ============================================================
task_terminate:
	lhld CURRENT_TCB
	mov a,h
	ora l
	rz			; No current task
	
	; Set state to FREE
	lxi d,TCB_STATE
	dad d
	mvi m,STATE_FREE
	
	; Clear current task
	lxi h,0
	shld CURRENT_TCB
	
	; Find next task
	call task_yield
	ret

; ============================================================
; GET TASK COUNT
; Output: A = number of tasks (non-free)
; ============================================================
get_task_count:
	lxi h,TCB_BASE
	mvi b,0			; Task counter
	mvi c,0			; Count

gtc_loop:
	mov a,b
	cpi MAX_TASKS
	jz gtc_done
	
	; Check if task is not free
	push h
	lxi d,TCB_STATE
	dad d
	mov a,m
	pop h
	
	cpi STATE_FREE
	jz gtc_skip
	
	; Count this task
	inr c

gtc_skip:
	lxi d,TCB_SIZE
	dad d
	inr b
	jmp gtc_loop

gtc_done:
	mov a,c
	ret

; ============================================================
; PRINT TASK LIST (for debugging)
; ============================================================
print_task_list:
	lxi h,TCB_BASE
	mvi b,0

ptl_loop:
	mov a,b
	cpi MAX_TASKS
	rz
	
	; Check if task is not free
	push h
	push b
	lxi d,TCB_STATE
	dad d
	mov a,m
	pop b
	pop h
	
	cpi STATE_FREE
	jz ptl_skip
	
	; Print task info
	; TODO: Add actual printing code
	
ptl_skip:
	lxi d,TCB_SIZE
	dad d
	inr b
	jmp ptl_loop

	ret
