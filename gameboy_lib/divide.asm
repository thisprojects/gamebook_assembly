; Division subroutine with error checking
; Input: A = dividend, B = divisor
; Output: A = quotient, carry flag set on error
divide:
    LD C, A              ; Save dividend
    LD A, B
    CP 0                 ; Check for divide by zero
    JP Z, div_error
    LD D, 0              ; D = quotient so far
div_loop:
    LD A, C
    CP B                 ; Is what's left smaller than the divisor?
    JR C, div_done       ; Yes - finished
    SUB B                ; Take one divisor off the dividend
    LD C, A
    INC D                ; ...and count it
    JR div_loop
div_done:
    LD A, D              ; A = quotient
    OR A                 ; Clear carry (success)
    RET

div_error:
    SCF                  ; Set carry flag (error)
    RET
