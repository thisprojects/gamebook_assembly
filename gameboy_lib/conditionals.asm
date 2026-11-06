INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]
    NOP
    JP Start
    DS $150 - @, 0       ; Room for the cartridge header (rgbfix fills it in)

SECTION "Main", ROM0[$150]
Start:
    CALL debug_init
    LD A, [var_a]        ; Load a
    CP 10                ; Compare with 10 (sets Z if equal)
    JP NZ, else_block    ; If not equal, jump to else

    ; If block (a == 10)
    LD A, 1
    LD [var_b], A
    LD HL, msg_equal
    CALL print_string    ; Print confirmation
    JP end_if            ; Skip the else block

else_block:
    ; Else block (a != 10)
    LD A, 0
    LD [var_b], A
    LD HL, msg_noteq
    CALL print_string    ; Print confirmation

end_if:
    LD A, 13
    RST $10              ; Newline

Done:
    HALT                 ; Nothing left to do: sleep forever
    NOP
    JR Done

msg_equal: DB "a equals 10", 0
msg_noteq: DB "a is not 10", 0
var_a: DB 10             ; Constant data lives in ROM...

SECTION "Variables", WRAM0
var_b: DS 1              ; ...but a variable we WRITE to must live in RAM

    INCLUDE "debug_output.asm"
