; cgb_demo.asm - Chapter 2: Game Boy Color palettes
; Build with   rgbfix -c   so the cartridge says it supports colour.
; On a Game Boy Color the map has a second layer: one attribute byte per
; tile, which names one of eight palettes of four colours each.
INCLUDE "boot.inc"

    CALL lcd_off

    ; --- 1. Write two palettes.  Colours are 15-bit: 0bbbbbgggggrrrrr ---
    LD A, $80                   ; start at palette byte 0, and count up after every write
    LDH [rBCPS], A
    LD HL, Palettes
    LD B, PalettesEnd - Palettes
.palette:
    LD A, [HL+]
    LDH [rBCPD], A
    DEC B
    JR NZ, .palette

    ; --- 2. Tiles: the same four solid colours as the previous demo ---
    LD HL, BandTiles
    LD DE, VRAM_TILES
    LD BC, BandTilesEnd - BandTiles
    CALL copy_bytes

    ; --- 3. Attributes live in VRAM bank 1, at the same addresses as the map ---
    LD A, 1
    LDH [rVBK], A
    LD HL, VRAM_MAP0
    LD C, SCREEN_H
.attr_row:
    LD A, C
    CP 10
    LD A, 0                     ; the top half of the screen uses palette 0 ...
    JR NC, .attr_set
    LD A, 1                     ; ... the bottom half palette 1
.attr_set:
    LD B, SCREEN_W
.attr_col:
    LD [HL+], A
    DEC B
    JR NZ, .attr_col
    LD DE, 32 - SCREEN_W
    ADD HL, DE
    DEC C
    JR NZ, .attr_row
    XOR A
    LDH [rVBK], A               ; back to bank 0 for the tile numbers

    ; --- 4. Tile numbers, as usual ---
    LD HL, VRAM_MAP0
    LD C, SCREEN_H
.row:
    LD DE, BandRow
    LD B, SCREEN_W
.col:
    LD A, [DE]
    LD [HL+], A
    INC DE
    DEC B
    JR NZ, .col
    LD DE, 32 - SCREEN_W
    ADD HL, DE
    DEC C
    JR NZ, .row

    XOR A
    LDH [rSCX], A
    LDH [rSCY], A
    CALL lcd_on
Done:
    HALT
    NOP
    JR Done

Palettes:
    DW $7FFF, $001F, $03E0, $7C00       ; palette 0: white, red, green, blue
    DW $0000, $03FF, $7FE0, $7C1F       ; palette 1: black, yellow, cyan, magenta
PalettesEnd:

BandRow:
    DB 0,0,0,0,0, 1,1,1,1,1, 2,2,2,2,2, 3,3,3,3,3

BandTiles:
    DB $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
    DB $FF,$00, $FF,$00, $FF,$00, $FF,$00, $FF,$00, $FF,$00, $FF,$00, $FF,$00
    DB $00,$FF, $00,$FF, $00,$FF, $00,$FF, $00,$FF, $00,$FF, $00,$FF, $00,$FF
    DB $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF
BandTilesEnd:

INCLUDE "gfx.asm"
