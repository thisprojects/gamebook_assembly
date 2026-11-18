; tiles_demo.asm - Chapter 1: tiles and the tile map
; Build:  rgbasm -I lib/ -o tiles_demo.o examples/tiles_demo.asm
;         rgblink -o tiles_demo.gb tiles_demo.o && rgbfix -v -p 0xFF tiles_demo.gb
INCLUDE "boot.inc"

    CALL lcd_off                ; VRAM is only safe to touch with the LCD off (or in VBlank)

    LD A, %11100100             ; Shades: colour 0 = white ... colour 3 = black
    CALL set_palette

    ; --- 1. Copy five tiles into VRAM, starting at tile 0 ---
    LD HL, TileData
    LD DE, VRAM_TILES
    LD BC, TileDataEnd - TileData
    CALL copy_bytes

    ; --- 2. Clear the whole 32x32 map to tile 0 (blank) ---
    XOR A
    CALL fill_map

    ; --- 3. Draw a frame of tile 3 around the 20x18 visible screen ---
    LD C, 0
.top_and_bottom:
    LD B, 0
.across:
    LD A, 3
    CALL set_tile               ; top row
    PUSH BC
    LD C, SCREEN_H - 1
    LD A, 3
    CALL set_tile               ; bottom row
    POP BC
    INC B
    LD A, B
    CP SCREEN_W
    JR C, .across
    ; (the loop above only needs to run once for C = 0)

    LD C, 1
.sides:
    LD B, 0
    LD A, 3
    CALL set_tile               ; left edge
    LD B, SCREEN_W - 1
    LD A, 3
    CALL set_tile               ; right edge
    INC C
    LD A, C
    CP SCREEN_H - 1
    JR C, .sides

    ; --- 4. Place a few individual tiles ---
    LD A, 1
    LD B, 5
    LD C, 5
    CALL set_tile               ; one solid block at column 5, row 5

    LD A, 4                     ; the four-shade stripe tile, three times in a row
    LD B, 9
    LD C, 9
    CALL set_tile
    LD B, 10
    CALL set_tile
    LD B, 11
    CALL set_tile

    ; --- 5. No scrolling, then switch the LCD back on ---
    XOR A
    LDH [rSCX], A
    LDH [rSCY], A
    CALL lcd_on

Done:
    HALT
    NOP
    JR Done

; Each tile is 16 bytes: 8 rows of 2 bytes.  For every pixel the first
; byte of the row supplies bit 0 of its colour, the second byte bit 1.
TileData:
    ; Tile 0: blank (every pixel colour 0)
    DB $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
    ; Tile 1: solid (every pixel colour 3)
    DB $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF
    ; Tile 2: checkerboard (colour 3 and colour 0)
    DB $AA,$AA, $55,$55, $AA,$AA, $55,$55, $AA,$AA, $55,$55, $AA,$AA, $55,$55
    ; Tile 3: a box outline in colour 3
    DB $FF,$FF, $81,$81, $81,$81, $81,$81, $81,$81, $81,$81, $81,$81, $FF,$FF
    ; Tile 4: four horizontal stripes, one for each colour 0, 1, 2, 3
    DB $00,$00, $00,$00, $FF,$00, $FF,$00, $00,$FF, $00,$FF, $FF,$FF, $FF,$FF
TileDataEnd:

INCLUDE "gfx.asm"
