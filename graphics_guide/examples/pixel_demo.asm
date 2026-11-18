; pixel_demo.asm - Chapter 3: drawing pixels on the canvas
INCLUDE "boot.inc"

    CALL lcd_off
    LD A, %11100100
    CALL set_palette
    XOR A
    CALL fill_map               ; tile 0 everywhere (we overwrite the visible part next)
    CALL canvas_map             ; map the 16x16 canvas tiles onto the screen

    XOR A
    CALL canvas_clear           ; white paper

    ; A diagonal of pixels in all four colours
    LD B, 0                     ; x
    LD C, 0                     ; y
.diag:
    LD A, B
    AND 3
    LD D, A                     ; colour = x mod 4
    PUSH BC
    CALL plot
    POP BC
    INC B
    INC C
    LD A, B
    CP 64
    JR C, .diag

    ; Draw a pixel, then toggle it twice with other pixels beside it
    LD B, 100
    LD C, 20
    LD D, 3
    CALL plot
    LD B, 101
    LD C, 20
    CALL toggle_pixel           ; colour 0 -> 3
    LD B, 100
    LD C, 20
    CALL toggle_pixel           ; colour 3 -> 0 : gone again

    CALL canvas_to_vram
    XOR A
    LDH [rSCX], A
    LDH [rSCY], A
    CALL lcd_on
Done:
    HALT
    NOP
    JR Done

INCLUDE "gfx.asm"
INCLUDE "canvas.asm"
