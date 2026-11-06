INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]
    NOP
    JP Start
    DS $150 - @, 0       ; Room for the cartridge header (rgbfix fills it in)

SECTION "Main", ROM0[$150]
Start:
    CALL debug_init          ; Set up the screen
    LD HL, msg
    CALL print_string        ; "INVERT!" appears at the top of the screen in black on white

    ; The palette register holds four 2-bit shades.  Right now it is %11100100:
    ;     bits 7-6 = 11  the text (shade 3, black)
    ;     bits 5-4 = 10
    ;     bits 3-2 = 01
    ;     bits 1-0 = 00  the background (shade 0, white)
    ; Use OR to force the two lowest bits to 1 without touching the other six.
    ; OR %00000011 makes the background shade 3, black.

    LD A, [rBGP]
    OR %00000011             ; Set the background shade to black
    LD [rBGP], A

    ; Now use AND to clear the top two bits.
    ; AND %00111111 forces bits 7-6 to 0 while leaving everything else unchanged.
    ; The text shade becomes 0, white - white letters on a black screen.

    LD A, [rBGP]
    AND %00111111            ; Set the text shade to white
    LD [rBGP], A

Done:
    HALT                 ; Nothing left to do: sleep forever
    NOP
    JR Done

msg: DB "INVERT!", 0

    INCLUDE "debug_output.asm"
