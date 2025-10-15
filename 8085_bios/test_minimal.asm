; Minimal 8085 BIOS test
        ORG 0000h

start:
        LXI SP, 0FFFEh   ; Set stack
        
        ; Output "Hi!"
        MVI A, 'H'
        OUT 1
        MVI A, 'i'
        OUT 1
        MVI A, '!'
        OUT 1
        MVI A, 13        ; CR
        OUT 1
        MVI A, 10        ; LF
        OUT 1

loop:
        JMP loop         ; Infinite loop
        
        END
