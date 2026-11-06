INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]
    NOP
    JP Start
    DS $150 - @, 0       ; Room for the cartridge header (rgbfix fills it in)

SECTION "Main", ROM0[$150]
Start:
    LD E, 0              ; E = current shade, starting at 0 (white)

colour_loop:
    LD A, E
    LD [rBGP], A         ; Set the whole screen to shade E ($00, $55, $AA or $FF)

    ; Delay loop: count BC down from 65536 to 0 - about 0.4 seconds
    LD BC, 0             ; 0 counts down through 65535, 65534 ... 1 - that is 65536 steps
delay_loop:
    DEC BC
    LD A, B
    OR C                 ; Is BC zero?  (DEC BC does not set the flags, so we test B OR C)
    JR NZ, delay_loop    ; No - keep counting down

    ; Advance to the next shade; stop when the addition wraps past 255
    LD A, E
    ADD A, $55           ; $00 -> $55 -> $AA -> $FF -> wraps to $54 and sets the carry flag
    LD E, A
    JP NC, colour_loop   ; No carry - go back and show the next shade

Done:
    HALT                 ; Nothing left to do: sleep forever
    NOP
    JR Done
