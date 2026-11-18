; palette_demo.asm - Chapter 2: the four shades and the palette register
; Four bands show the four colours.  Every second the palette register
; steps through a fade to white and back, without a single tile being touched.
DEF FADE_FRAMES EQU 60

SECTION "PaletteVars", WRAM0
wStep:  DS 1                    ; which entry of FadeTable is showing
wTimer: DS 1                    ; frames until the next step

INCLUDE "boot.inc"

    CALL lcd_off

    LD HL, BandTiles            ; four solid tiles, one for each colour 0-3
    LD DE, VRAM_TILES
    LD BC, BandTilesEnd - BandTiles
    CALL copy_bytes

    LD HL, VRAM_MAP0            ; draw the same 20 tiles on each of 18 rows
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
    LD DE, 32 - SCREEN_W        ; skip the rest of the 32-tile map row
    ADD HL, DE
    DEC C
    JR NZ, .row

    XOR A
    LD [wStep], A
    LDH [rSCX], A
    LDH [rSCY], A
    LD A, FADE_FRAMES
    LD [wTimer], A
    LD A, [FadeTable]
    LDH [rBGP], A
    CALL lcd_on

MainLoop:
    CALL wait_vblank
    LD A, [wTimer]
    DEC A
    LD [wTimer], A
    JR NZ, MainLoop
    LD A, FADE_FRAMES
    LD [wTimer], A

    LD A, [wStep]               ; next entry of the table, wrapping after the sixth
    INC A
    CP 6
    JR C, .step_ok
    XOR A
.step_ok:
    LD [wStep], A
    LD E, A
    LD D, 0
    LD HL, FadeTable
    ADD HL, DE
    LD A, [HL]
    LDH [rBGP], A               ; one write recolours the whole screen
    JR MainLoop

; A palette byte holds four 2-bit shades: colour 3 in the top bits, colour 0 in the bottom.
; %11100100 means  colour 3 -> shade 3 (black), 2 -> 2, 1 -> 1, 0 -> 0 (white).
FadeTable:
    DB %11100100                ; normal
    DB %10010000                ; every shade one step lighter
    DB %01000000                ; two steps lighter
    DB %00000000                ; everything white
    DB %01000000
    DB %10010000

BandRow:
    DB 0,0,0,0,0, 1,1,1,1,1, 2,2,2,2,2, 3,3,3,3,3

BandTiles:
    DB $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00   ; colour 0
    DB $FF,$00, $FF,$00, $FF,$00, $FF,$00, $FF,$00, $FF,$00, $FF,$00, $FF,$00   ; colour 1
    DB $00,$FF, $00,$FF, $00,$FF, $00,$FF, $00,$FF, $00,$FF, $00,$FF, $00,$FF   ; colour 2
    DB $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF   ; colour 3
BandTilesEnd:

INCLUDE "gfx.asm"
