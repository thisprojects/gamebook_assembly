; invader.asm - Chapter 6: hardware sprites
; Three animated invaders march across a checkerboard; a UFO glides in
; from the left edge and out through the right edge; a fourth invader walks
; *behind* the bunkers.  No clipping, masking or layering code is needed - the
; hardware does all three.  The UFO uses the second sprite palette.
SECTION "InvaderVars", WRAM0
wFrame: DS 1
wInvX:  DS 1
wUfoX:  DS 1

INCLUDE "boot.inc"

    CALL lcd_off
    LD A, %11100100
    CALL set_palette
    LD A, %00011011             ; sprite palette 1 is the reverse of the normal one: used by the UFO
    LDH [rOBP1], A

    LD HL, SpriteTiles
    LD DE, VRAM_TILES
    LD BC, SpriteTilesEnd - SpriteTiles
    CALL copy_bytes

    LD A, 2                     ; checkerboard backdrop
    CALL fill_map
    LD HL, BunkerColumns        ; a row of bunker blocks along map row 15
.bunker:
    LD A, [HL+]
    CP $FF
    JR Z, .bunkers_done
    LD B, A
    LD C, 15
    LD A, 1
    PUSH HL
    CALL set_tile
    POP HL
    JR .bunker
.bunkers_done:

    XOR A
    LDH [rSCX], A
    LDH [rSCY], A
    LD [wFrame], A
    LD A, 20
    LD [wInvX], A
    XOR A
    LD [wUfoX], A

    CALL oam_init               ; copy the DMA routine into HRAM, hide all sprites
    CALL lcd_on

MainLoop:
    CALL wait_vblank
    CALL hOAMDMA                ; copy last frame's shadow OAM into real OAM

    ; --- advance the game state ---
    LD A, [wFrame]
    INC A
    LD [wFrame], A
    AND 1
    JR NZ, .no_march
    LD A, [wInvX]
    INC A
    CP 120
    JR C, .march_ok
    LD A, 20
.march_ok:
    LD [wInvX], A
.no_march:
    LD A, [wUfoX]
    INC A
    LD [wUfoX], A

    ; --- build this frame's sprite list ---
    CALL oam_begin

    LD A, [wFrame]
    SWAP A
    AND 1                       ; animation frame flips every 16 frames
    LD HL, InvaderA
    JR Z, .frame_a
    LD HL, InvaderB
.frame_a:
    PUSH HL
    LD A, [wInvX]
    LD B, A
    LD C, 40
    CALL draw_metasprite
    POP HL
    PUSH HL
    LD A, [wInvX]
    LD B, A
    LD C, 56
    CALL draw_metasprite
    POP HL
    LD A, [wInvX]
    LD B, A
    LD C, 72
    CALL draw_metasprite

    LD A, [wInvX]               ; the fourth invader walks along the bunker row, behind the bunkers
    LD B, A
    LD C, 120
    LD HL, InvaderBehind
    CALL draw_metasprite

    LD A, [wUfoX]
    SUB 16                      ; x = wUfoX - 16: wraps below zero, so it enters from the left edge
    LD B, A
    LD C, 20
    LD HL, Ufo
    CALL draw_metasprite

    CALL oam_end
    JR MainLoop

BunkerColumns: DB 3, 4, 5, 9, 10, 11, 14, 15, 16, $FF

; Each invader is two sprites: a left half, and the same tile again
; flipped horizontally for the right half.
InvaderA:
    DB 2
    DB 0, 0, 3, 0
    DB 0, 8, 3, OAMF_XFLIP
InvaderB:
    DB 2
    DB 0, 0, 4, 0
    DB 0, 8, 4, OAMF_XFLIP
InvaderBehind:                  ; priority flag: hidden wherever the background is not colour 0
    DB 2
    DB 0, 0, 3, OAMF_PRI
    DB 0, 8, 3, OAMF_XFLIP | OAMF_PRI
Ufo:
    DB 2
    DB 0, 0, 5, OAMF_PAL1       ; drawn with sprite palette 1
    DB 0, 8, 5, OAMF_XFLIP | OAMF_PAL1

SpriteTiles:
    ; Tile 0: blank
    DB $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
    ; Tile 1: bunker block (colour 2)
    DB $00,$FF, $00,$FF, $00,$FF, $00,$FF, $00,$FF, $00,$FF, $00,$FF, $00,$FF
    ; Tile 2: checkerboard backdrop (colour 1 on colour 0)
    DB $AA,$00, $55,$00, $AA,$00, $55,$00, $AA,$00, $55,$00, $AA,$00, $55,$00
    ; Tile 3: invader, left half, legs in
    DB $03,$03, $0F,$0F, $1F,$1F, $39,$39, $3F,$3F, $06,$06, $0D,$0D, $30,$30
    ; Tile 4: invader, left half, legs out
    DB $03,$03, $0F,$0F, $1F,$1F, $39,$39, $3F,$3F, $0C,$0C, $1A,$1A, $0C,$0C
    ; Tile 5: UFO, left half (colour 2)
    DB $00,$00, $00,$00, $0F,$0F, $3F,$3F, $5F,$5F, $FF,$FF, $38,$38, $10,$10
SpriteTilesEnd:

INCLUDE "gfx.asm"
INCLUDE "oam.asm"
