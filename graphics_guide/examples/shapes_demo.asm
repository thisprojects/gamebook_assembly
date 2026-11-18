; shapes_demo.asm - Chapter 5: rectangles, circles and a flood fill
INCLUDE "boot.inc"

    CALL lcd_off
    LD A, %11100100
    CALL set_palette
    XOR A
    CALL fill_map
    CALL canvas_map
    XOR A
    CALL canvas_clear

    LD A, 3
    LD [wColour], A
    LD B, 4                     ; hollow rectangle
    LD C, 4
    LD D, 50
    LD E, 30
    CALL draw_rect

    LD A, 2
    LD [wColour], A
    LD B, 70                    ; filled rectangle
    LD C, 4
    LD D, 40
    LD E, 30
    CALL fill_rect

    LD A, 3
    LD [wColour], A
    LD B, 32                    ; circle outline: centre (32, 80), radius 24
    LD C, 80
    LD E, 24
    CALL draw_circle

    LD A, 1
    LD [wColour], A
    LD B, 90                    ; filled circle: centre (90, 85), radius 20
    LD C, 85
    LD E, 20
    CALL fill_circle

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
