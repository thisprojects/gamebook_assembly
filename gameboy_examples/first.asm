; Save this as first.asm
INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]
    NOP
    JP Start
    DS $150 - @, 0       ; Room for the cartridge header (rgbfix fills it in)

SECTION "Main", ROM0[$150]
Start:
    CALL debug_init      ; Set up the screen (the Game Boy has no ROM to do it for us)
    LD A, 42             ; 42 is the character code of '*'
    RST $10              ; Print character (RST $10 jumps to print_char)

Done:
    HALT                 ; Nothing left to do: sleep forever
    NOP
    JR Done

    INCLUDE "debug_output.asm"
