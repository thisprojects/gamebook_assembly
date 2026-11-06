INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]
    NOP
    JP Start
    DS $150 - @, 0       ; Room for the cartridge header (rgbfix fills it in)

SECTION "Main", ROM0[$150]
Start:
    ; Set up the screen
    CALL debug_init

    ; Set print position to row 10, column 5
    LD B, 10             ; row 10
    LD C, 5              ; column 5
    CALL set_cursor      ; position the cursor

    ; Now print a message at that position
    LD A, 'X'
    RST $10

Done:
    HALT                 ; Nothing left to do: sleep forever
    NOP
    JR Done

    INCLUDE "debug_output.asm"
