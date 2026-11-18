; flood_demo.asm - Chapter 5: a shadow map and a flood fill
; A box is divided into two rooms by a wall; the flood fill paints
; one room and stops at the walls.
INCLUDE "boot.inc"

DEF WALL  EQU 2
DEF PAINT EQU 1

    CALL lcd_off
    LD A, %11100100
    CALL set_palette

    LD HL, FillTiles
    LD DE, VRAM_TILES
    LD BC, FillTilesEnd - FillTiles
    CALL copy_bytes

    XOR A
    CALL shadow_fill            ; everything blank in the shadow copy

    ; The outer box (columns 4-15, rows 3-11) and a dividing wall, drawn with tile lines
    LD A, WALL
    LD B, 4
    LD C, 3
    LD E, 12
    CALL shadow_hline           ; top
    LD A, WALL
    LD B, 4
    LD C, 11
    LD E, 12
    CALL shadow_hline           ; bottom
    LD A, WALL
    LD B, 4
    LD C, 3
    LD E, 9
    CALL shadow_vline           ; left
    LD A, WALL
    LD B, 15
    LD C, 3
    LD E, 9
    CALL shadow_vline           ; right
    LD A, WALL
    LD B, 9
    LD C, 3
    LD E, 9
    CALL shadow_vline           ; the dividing wall

    ; Flood the left-hand room, starting from inside it
    LD A, PAINT
    LD B, 6
    LD C, 6
    CALL flood_fill

    CALL shadow_to_vram         ; copy the finished picture to the screen
    XOR A
    LDH [rSCX], A
    LDH [rSCY], A
    CALL lcd_on
Done:
    HALT
    NOP
    JR Done

FillTiles:
    ; Tile 0: blank
    DB $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
    ; Tile 1: paint (dotted)
    DB $AA,$00, $00,$00, $55,$00, $00,$00, $AA,$00, $00,$00, $55,$00, $00,$00
    ; Tile 2: wall (solid)
    DB $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF
FillTilesEnd:

INCLUDE "gfx.asm"
INCLUDE "tilemap.asm"
