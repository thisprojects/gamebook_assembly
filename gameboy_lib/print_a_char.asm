INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]
    NOP
    JP Start
    DS $150 - @, 0       ; Room for the cartridge header (rgbfix fills it in)

SECTION "Main", ROM0[$150]
Start:
    ; Set up the screen
    CALL debug_init

    ; Print 'A' using RST $10
    LD A, 'A'
    RST $10

Done:
    HALT                 ; Nothing left to do: sleep forever
    NOP
    JR Done

    INCLUDE "debug_output.asm"
