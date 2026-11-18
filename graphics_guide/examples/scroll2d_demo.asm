; scroll2d_demo.asm - Chapter 7: scrolling in two directions
; The camera walks a square: right, down, left, up, 160 pixels each way, over a
; 64 x 64 tile world.  Whenever it moves into a new tile, one new column or one
; new row of the world is written into the map just ahead of the screen.
SECTION "Scroll2DVars", WRAM0
wCamX:   DS 1
wCamY:   DS 1
wPhase:  DS 1                   ; 0 = right, 1 = down, 2 = left, 3 = up
wCount:  DS 1                   ; frames left in this phase
wDX:     DS 1
wDY:     DS 1
wTmp:    DS 1

INCLUDE "boot.inc"

DEF PHASE_LENGTH EQU 160

    CALL lcd_off
    LD A, %11100100
    CALL set_palette
    LD HL, WorldTiles
    LD DE, VRAM_TILES
    LD BC, WorldTilesEnd - WorldTiles
    CALL copy_bytes

    LD B, 0                     ; fill the first 21 map columns (19 rows each: more than the 18 visible)
.fill:
    LD A, B
    PUSH BC
    LD B, 0
    CALL stream_world_column
    POP BC
    INC B
    LD A, B
    CP 21
    JR NZ, .fill

    XOR A
    LD [wCamX], A
    LD [wCamY], A
    LD [wPhase], A
    LDH [rSCX], A
    LDH [rSCY], A
    LD A, PHASE_LENGTH
    LD [wCount], A
    LD A, LCDC_NORMAL
    LDH [rLCDC], A

MainLoop:
    CALL wait_vblank

    ; --- this phase's direction: PhaseDX/PhaseDY hold -1, 0 or +1 for each phase ---
    LD A, [wPhase]
    LD E, A
    LD D, 0
    LD HL, PhaseDX
    ADD HL, DE
    LD A, [HL]
    LD [wDX], A
    LD HL, PhaseDY
    ADD HL, DE
    LD A, [HL]
    LD [wDY], A

    ; --- horizontal movement ---
    LD A, [wDX]
    OR A
    JR Z, .no_x
    LD A, [wCamX]
    LD B, A                     ; B = old position
    LD A, [wDX]
    ADD B
    LD [wCamX], A
    LDH [rSCX], A               ; the scroll register: this is the actual scrolling
    SRL A
    SRL A
    SRL A
    LD C, A                     ; C = tile column now at the left edge
    LD A, B
    SRL A
    SRL A
    SRL A
    CP C
    JR Z, .no_x                 ; still in the same tile: nothing to stream
    LD A, [wDX]
    BIT 7, A
    LD A, C
    JR NZ, .stream_x            ; moving left: the new column is the one at the left edge
    ADD 20                      ; moving right: the one just beyond the right edge
.stream_x:
    LD [wTmp], A
    LD A, [wCamY]
    SRL A
    SRL A
    SRL A
    LD B, A                     ; first row to write = the row at the top edge
    LD A, [wTmp]
    CALL stream_world_column
.no_x:

    ; --- vertical movement ---
    LD A, [wDY]
    OR A
    JR Z, .no_y
    LD A, [wCamY]
    LD B, A
    LD A, [wDY]
    ADD B
    LD [wCamY], A
    LDH [rSCY], A
    SRL A
    SRL A
    SRL A
    LD C, A                     ; C = tile row now at the top edge
    LD A, B
    SRL A
    SRL A
    SRL A
    CP C
    JR Z, .no_y
    LD A, [wDY]
    BIT 7, A
    LD A, C
    JR NZ, .stream_y            ; moving up: the new row is the one at the top edge
    ADD 18                      ; moving down: the one just below the bottom edge
.stream_y:
    LD [wTmp], A
    LD A, [wCamX]
    SRL A
    SRL A
    SRL A
    LD B, A                     ; first column to write = the column at the left edge
    LD A, [wTmp]
    CALL stream_world_row
.no_y:

    ; --- after PHASE_LENGTH frames, turn the corner ---
    LD A, [wCount]
    DEC A
    LD [wCount], A
    JP NZ, MainLoop
    LD A, PHASE_LENGTH
    LD [wCount], A
    LD A, [wPhase]
    INC A
    AND 3
    LD [wPhase], A
    JP MainLoop

PhaseDX: DB 1, 0, $FF, 0
PhaseDY: DB 0, 1, 0, $FF

WorldTiles:
    ; Tile 0: grass (sparse dots, colour 1)
    DB $00,$00, $10,$00, $00,$00, $00,$00, $00,$00, $01,$00, $00,$00, $00,$00
    ; Tile 1: path (diagonal hatching, colour 2)
    DB $00,$81, $00,$42, $00,$24, $00,$18, $00,$81, $00,$42, $00,$24, $00,$18
    ; Tile 2: flower (colour 3)
    DB $00,$00, $18,$18, $3C,$3C, $18,$18, $18,$18, $00,$00, $00,$00, $00,$00
WorldTilesEnd:

INCLUDE "gfx.asm"
INCLUDE "scroll.asm"
