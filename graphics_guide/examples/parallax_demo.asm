; parallax_demo.asm - Chapter 7: a raster effect with the STAT interrupt
; The top half of the screen scrolls at half the speed of the bottom
; half.  The LCD can interrupt the CPU at any scanline, so one line of
; code changes rSCX part-way down every frame.
DEF SPLIT_LINE EQU 72           ; the first scanline of the fast (bottom) layer

SECTION "VBlankVector", ROM0[$40]
    JP VBlankHandler
SECTION "STATVector", ROM0[$48]
    JP STATHandler

SECTION "ParallaxVars", WRAM0
wCamX:    DS 1                  ; camera for the fast layer
wFarX:    DS 1                  ; slower camera for the far layer
wVBlank:  DS 1                  ; set to 1 by the VBlank handler

INCLUDE "boot.inc"

    CALL lcd_off
    LD A, %11100100
    CALL set_palette
    LD HL, BarTiles
    LD DE, VRAM_TILES
    LD BC, BarTilesEnd - BarTiles
    CALL copy_bytes

    ; Every map column gets a tile with one dark bar in a different place
    LD HL, VRAM_MAP0
    LD C, 32                    ; 32 rows
.row:
    LD B, 0                     ; column
.col:
    LD A, B
    ADD A
    ADD B                       ; column * 3
    LD D, A
    LD A, B
    SRL A
    SRL A
    ADD D                       ; + column / 4
    AND 7                       ; bar position 0-7
    LD [HL+], A
    INC B
    LD A, B
    CP 32
    JR NZ, .col
    DEC C
    JR NZ, .row

    XOR A
    LD [wCamX], A
    LD [wFarX], A
    LD [wVBlank], A
    LDH [rSCX], A
    LDH [rSCY], A

    LD A, SPLIT_LINE - 1        ; ask for an interrupt just before the split line is drawn
    LDH [rLYC], A
    LD A, STATF_LYC
    LDH [rSTAT], A
    LD A, IEF_VBLANK | IEF_STAT
    LDH [rIE], A
    XOR A
    LDH [rIF], A
    CALL lcd_on
    EI

MainLoop:
.wait:
    HALT                        ; sleep until an interrupt happens
    NOP
    LD A, [wVBlank]
    OR A
    JR Z, .wait                 ; the STAT interrupt also wakes us: ignore it
    XOR A
    LD [wVBlank], A

    LD A, [wCamX]               ; fast layer: one pixel a frame
    INC A
    LD [wCamX], A
    AND 1                       ; far layer: one pixel every other frame
    JR NZ, MainLoop
    LD A, [wFarX]
    INC A
    LD [wFarX], A
    JR MainLoop

; --- Start of VBlank: the top of the next frame uses the far layer's scroll ---
VBlankHandler:
    PUSH AF
    LD A, [wFarX]
    LDH [rSCX], A
    LD A, 1
    LD [wVBlank], A
    POP AF
    RETI

; --- Just before line SPLIT_LINE: switch to the fast layer's scroll ---
STATHandler:
    PUSH AF
    LD A, [wCamX]
    LDH [rSCX], A
    POP AF
    RETI

; Tile n has one dark vertical bar, n pixels from the left edge
BarTiles:
FOR n, 8
    REPT 8
        DB $80 >> n, $80 >> n
    ENDR
ENDR
BarTilesEnd:

INCLUDE "gfx.asm"
