; line_demo.asm - Chapter 4: lines on the canvas
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

    ; A box made of horizontal and vertical lines
    LD B, 0
    LD C, 0
    LD D, 3
    LD E, 128
    CALL draw_hline             ; top edge
    LD B, 0
    LD C, 127
    LD D, 3
    LD E, 128
    CALL draw_hline             ; bottom edge
    LD B, 0
    LD C, 0
    LD D, 3
    LD E, 128
    CALL draw_vline             ; left edge
    LD B, 127
    LD C, 0
    LD D, 3
    LD E, 128
    CALL draw_vline             ; right edge

    ; Diagonals and a few lines of other slopes
    LD B, 0
    LD C, 0
    LD D, 127
    LD E, 127
    CALL draw_line
    LD A, 2
    LD [wColour], A
    LD B, 127
    LD C, 0
    LD D, 0
    LD E, 127
    CALL draw_line
    LD A, 1
    LD [wColour], A
    LD B, 10
    LD C, 100
    LD D, 120
    LD E, 30
    CALL draw_line
    LD B, 64
    LD C, 5
    LD D, 70
    LD E, 120
    CALL draw_line

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
