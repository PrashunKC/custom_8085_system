; 8085 Monitor BIOS - simple console and Intel HEX loader
; Target: 8080/8085 instruction set (no undocumented ops)
; Assembles with Macroassembler AS (asl) or other 8080 assemblers.
;
; I/O contract (adjust equates as needed):
;  - IN from CONIN_PORT returns ASCII of next key, or 0 if none (monitor busy-waits)
;  - OUT to CONOUT_PORT writes ASCII to console
;
CONIN_PORT	equ	0
CONOUT_PORT	equ	1
STACK_TOP	equ	0FFFEh

	org 0000h

start:
	lxi sp, STACK_TOP
	call banner
	jmp cmd_loop

; ---------------- Console I/O -----------------
; A = char to output
con_putc:
	out CONOUT_PORT
	ret

; print CR LF
con_nl:
	mvi a,13
	call con_putc
	mvi a,10
	call con_putc
	ret

; blocking getc: waits until non-zero IN
con_getc:
	in CONIN_PORT
	ora a
	jz con_getc
	ret

; getc and echo
con_getc_echo:
	call con_getc
	push psw
	call con_putc
	pop psw
	ret

; print zero-terminated string at HL
con_puts:
	mov a,m
	ora a
	rz
	call con_putc
	inx h
	jmp con_puts

; ---------------- Hex helpers -----------------
; put nibble in A (0..15) as ASCII
put_hex_nibble:
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

; print A as two hex digits
put_hex8:
	push psw
	push b
	mov b,a
	ani 0F0h
	rlc
	rlc
	rlc
	rlc
	call put_hex_nibble
	mov a,b
	ani 0Fh
	call put_hex_nibble
	pop b
	pop psw
	ret

; print HL as four hex digits
put_hex16:
	push psw
	mov a,h
	call put_hex8
	mov a,l
	call put_hex8
	pop psw
	ret

; Read a hex digit from input; skips spaces and CR/LF
; Returns A=nibble (0..15), CY=0 on success. CY=1 on error (non-hex)
read_hex_digit:
	rhd_loop:
	call con_getc_echo
	cpi ' '
	jz rhd_loop
	cpi 13
	jz rhd_loop
	cpi 10
	jz rhd_loop
	; Upper-case: A &= 0xDF
	ani 0DFh
	cpi '0'
	jc rhd_err
	cpi '9'+1
	jc rhd_09
	cpi 'A'
	jc rhd_err
	cpi 'F'+1
	jc rhd_AF
	stc
	ret
rhd_09:
	sui '0'
	stc
	cmc
	ret
rhd_AF:
	sui 'A'
	adi 10
	stc
	cmc
	ret
rhd_err:
	stc
	ret

; Read two hex digits -> A=byte, CY=0 ok
read_hex_byte:
	push b
	call read_hex_digit
	jc rhb_err
	mov b,a		; high nibble
	call read_hex_digit
	jc rhb_err
	; A low nibble, B high nibble
	ani 0Fh
	mov c,a
	mov a,b
	ani 0Fh
	rlc
	rlc
	rlc
	rlc
	ora c
	stc
	cmc
	pop b
	ret
rhb_err:
	stc
	pop b
	ret

; Read four hex digits -> HL=word, CY=0 ok
read_hex_word:
	push b
	call read_hex_byte
	jc rhw_err
	mov h,a
	call read_hex_byte
	jc rhw_err
	mov l,a
	stc
	cmc
	pop b
	ret
rhw_err:
	stc
	pop b
	ret

; Eat until end of line (CR or LF)
eat_to_eol:
	call con_getc
	cpi 13
	jz ete_done
	cpi 10
	jz ete_done
	jmp eat_to_eol
ete_done:
	ret

; ---------------- Messages --------------------
msg_banner:
	db 13,10,'8085 MONITOR BIOS',13,10,0
msg_prompt:
	db '>',0
msg_help:
	db 13,10,'Commands:',13,10
	db ' H        Help',13,10
	db ' D a n    Dump n bytes from addr a',13,10
	db ' M a      Modify bytes at addr a (end with .)',13,10
	db ' G a      Go to addr a',13,10
	db ' L        Load Intel HEX',13,10,0
msg_ok:
	db 'OK',13,10,0

banner:
	lxi h,msg_banner
	call con_puts
	ret

prompt:
	lxi h,msg_prompt
	call con_puts
	ret

; ---------------- Command loop ----------------
cmd_loop:
	call prompt
	call con_getc_echo
	ani 0DFh	; uppercase
	cpi 'H'
	jz cmd_help
	cpi 'D'
	jz cmd_dump
	cpi 'M'
	jz cmd_mod
	cpi 'G'
	jz cmd_go
	cpi 'L'
	jz cmd_load
	call con_nl
	jmp cmd_loop

cmd_help:
	lxi h,msg_help
	call con_puts
	jmp cmd_loop

; D addr len  (addr=4 hex digits, len=2 hex digits)
cmd_dump:
	call read_hex_word
	jc cmd_bad
	push h		; save start
	call read_hex_byte
	jc cmd_bad_pop
	mov e,a		; remaining count in E (<=255)
	mvi d,0
	pop h		; HL=start
	; loop
cd_top:
	mov a,d
	ora e
	jz cd_done
	; print address
	push h
	mov a,h
	call put_hex8
	mov a,l
	call put_hex8
	mvi a,':'
	call con_putc
	mvi a,' '
	call con_putc
	pop h
	; determine count this line: C = min(16, remaining)
	push d
	mov a,e
	cpi 16
	jc cd_set_rem
	mvi c,16
	jmp cd_set_done
cd_set_rem:
	mov c,a
cd_set_done:
cd_line:
	mov a,c
	ora a
	jz cd_after_line
	mov a,m
	call put_hex8
	mvi a,' '
	call con_putc
	inx h
	dcr c
	jmp cd_line
cd_after_line:
	pop d
	; subtract C from DE (we lost C), recompute like before
	mov a,e
	cpi 16
	jc cd_sub_rem
	; subtract 16
	sui 16
	mov e,a
	jmp cd_line_done
cd_sub_rem:
	; subtract previous remaining which was <16: set E=0
	xra a
	mov e,a
cd_line_done:
	call con_nl
	jmp cd_top
cd_done:
	call con_nl
	jmp cmd_loop

cmd_bad_pop:
	pop h
cmd_bad:
	call con_nl
	jmp cmd_loop

; M addr
cmd_mod:
	call read_hex_word
	jc cmd_bad
	; HL=start
cm_next:
	; show addr and current byte
	push h
	mov a,h
	call put_hex8
	mov a,l
	call put_hex8
	mvi a,'='
	call con_putc
	mov a,m
	call put_hex8
	mvi a,'>'
	call con_putc
	pop h
	; read first char
	call con_getc_echo
	cpi '.'
	jz cm_exit
	cpi 13
	jz cm_cr
	; convert first nibble in A
	ani 0DFh
	mov b,a
	cpi '0'
	jc cm_flush
	cpi '9'+1
	jc cm_d1_num
	cpi 'A'
	jc cm_flush
	cpi 'F'+1
	jnc cm_flush
	; A..F
	sui 'A'
	adi 10
	jmp cm_d1_have
cm_d1_num:
	sui '0'
cm_d1_have:
	ani 0Fh
	mov b,a		; B = first nibble
	; second nibble
	call con_getc_echo
	ani 0DFh
	cpi '0'
	jc cm_flush
	cpi '9'+1
	jc cm_d2_num
	cpi 'A'
	jc cm_flush
	cpi 'F'+1
	jnc cm_flush
	sui 'A'
	adi 10
	jmp cm_d2_have
cm_d2_num:
	sui '0'
cm_d2_have:
	ani 0Fh
	mov c,a		; C = second nibble
	mov a,b
	rlc
	rlc
	rlc
	rlc
	ani 0F0h
	ora c
	mov m,a
	inx h
	; flush rest of line
	call eat_to_eol
	jmp cm_next
cm_cr:
	inx h
	jmp cm_next
cm_flush:
	call eat_to_eol
	jmp cm_next
cm_exit:
	call con_nl
	jmp cmd_loop

; G addr
cmd_go:
	call read_hex_word
	jc cmd_bad
	pchl

; L: Intel HEX loader (record types 00 data, 01 EOF)
cmd_load:
	call con_nl
ll_wait:
	; wait for ':'
	call con_getc
	cpi ':'
	jnz ll_wait
	; byte count
	call read_hex_byte
	jc cmd_bad
	mov b,a		; count
	; address
	call read_hex_word
	jc cmd_bad
	; type
	call read_hex_byte
	jc cmd_bad
	mov c,a		; type
	cpi 00h
	jz ll_type00
	cpi 01h
	jz ll_type01
	; skip other types
ll_skip:
	mov a,b
	ora a
	jz ll_chk
	call read_hex_byte
	dcr b
	jmp ll_skip
ll_chk:
	; checksum
	call read_hex_byte
	; end of line
	call eat_to_eol
	jmp ll_wait

ll_type00:
	; write B data bytes starting at HL
ll_dloop:
	mov a,b
	ora a
	jz ll_after00
	call read_hex_byte
	mov m,a
	inx h
	dcr b
	jmp ll_dloop
ll_after00:
	; checksum
	call read_hex_byte
	call eat_to_eol
	jmp ll_wait

ll_type01:
	; checksum and EOL
	call read_hex_byte
	call eat_to_eol
	lxi h,msg_ok
	call con_puts
	jmp cmd_loop

	end
