INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]
    NOP
    JP Start
    DS $150 - @, 0       ; Room for the cartridge header (rgbfix fills it in)

SECTION "Main", ROM0[$150]
Start:
    CALL debug_init      ; Set up screen output (do this once)

    LD HL, msg           ; Point HL at our string
    CALL print_string    ; Prints: Hello!
    LD A, 13
    RST $10              ; Newline

    LD A, 42
    CALL print_number    ; Prints: 42
    LD A, 13
    RST $10              ; Newline

    LD A, '*'
    CALL print_char      ; Prints: *

Done:
    HALT                 ; Nothing left to do: sleep forever
    NOP
    JR Done

msg: DB "Hello!", 0

    INCLUDE "debug_output.asm"
