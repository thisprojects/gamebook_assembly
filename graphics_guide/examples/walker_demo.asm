; walker_demo.asm - Chapter 11: a character you can steer, with walls and a walk cycle
; D-pad moves a tall (8x16) sprite, B held makes it run, A turns it round.
; The room is a map of tiles; before every step the program looks up the
; tiles the character would be standing on and refuses a step into a wall.
SECTION "WalkerVars", WRAM0
wPX:    DS 1                    ; the player's position (screen pixels, top-left corner)
wPY:    DS 1
wFlags: DS 1                    ; sprite flags: bit 5 flips the player horizontally
wSpeed: DS 1                    ; pixels per frame
wAnim:  DS 1                    ; counts steps taken; picks the walk frame

INCLUDE "boot.inc"

DEF TILE_FLOOR EQU 1
DEF TILE_WALL  EQU 2

    CALL lcd_off
    LD A, %11100100
    CALL set_palette
    LD HL, WalkerTiles
    LD DE, VRAM_TILES
    LD BC, WalkerTilesEnd - WalkerTiles
    CALL copy_bytes

    ; --- Build the room in the shadow map: floor, a border wall, and a wall across the middle ---
    LD A, TILE_FLOOR
    CALL shadow_fill
    LD A, TILE_WALL
    LD B, 0
    LD C, 0
    LD E, SCREEN_W
    CALL shadow_hline           ; top
    LD A, TILE_WALL
    LD B, 0
    LD C, SCREEN_H - 1
    LD E, SCREEN_W
    CALL shadow_hline           ; bottom
    LD A, TILE_WALL
    LD B, 0
    LD C, 0
    LD E, SCREEN_H
    CALL shadow_vline           ; left
    LD A, TILE_WALL
    LD B, SCREEN_W - 1
    LD C, 0
    LD E, SCREEN_H
    CALL shadow_vline           ; right
    LD A, TILE_WALL
    LD B, 10
    LD C, 3
    LD E, 11
    CALL shadow_vline           ; the wall across the middle: column 10, rows 3-13
    CALL shadow_to_vram

    XOR A
    LDH [rSCX], A
    LDH [rSCY], A
    LD [wFlags], A
    LD [wAnim], A
    LD [wJoy], A
    LD A, 40
    LD [wPX], A
    LD A, 64
    LD [wPY], A
    CALL oam_init
    CALL vblank_init
    LD A, LCDC_NORMAL | LCDCF_OBJ16     ; sprites are now 8x16: each uses a tile pair
    LDH [rLCDC], A
    EI

MainLoop:
    CALL wait_frame
    CALL read_joypad

    LD A, [wJoyNew]             ; A pressed this frame: turn round
    AND PADF_A
    JR Z, .no_turn
    LD A, [wFlags]
    XOR OAMF_XFLIP
    LD [wFlags], A
.no_turn:

    LD A, 1                     ; speed: 1 pixel a frame, or 2 with B held
    LD B, A
    LD A, [wJoy]
    AND PADF_B
    JR Z, .walk
    INC B
.walk:
    LD A, B
    LD [wSpeed], A

    ; Each direction: work out where the step would end up, and take it only if that spot is free.
    LD A, [wJoy]
    AND PADF_RIGHT
    JR Z, .no_right
    LD A, [wSpeed]
    LD B, A
    LD A, [wPX]
    ADD B
    LD B, A
    LD A, [wPY]
    LD C, A
    CALL blocked
    JR Z, .no_right
    LD A, B
    LD [wPX], A
    CALL stepped
.no_right:
    LD A, [wJoy]
    AND PADF_LEFT
    JR Z, .no_left
    LD A, [wSpeed]
    LD B, A
    LD A, [wPX]
    SUB B
    LD B, A
    LD A, [wPY]
    LD C, A
    CALL blocked
    JR Z, .no_left
    LD A, B
    LD [wPX], A
    CALL stepped
.no_left:
    LD A, [wJoy]
    AND PADF_UP
    JR Z, .no_up
    LD A, [wSpeed]
    LD C, A
    LD A, [wPY]
    SUB C
    LD C, A
    LD A, [wPX]
    LD B, A
    CALL blocked
    JR Z, .no_up
    LD A, C
    LD [wPY], A
    CALL stepped
.no_up:
    LD A, [wJoy]
    AND PADF_DOWN
    JR Z, .no_down
    LD A, [wSpeed]
    LD C, A
    LD A, [wPY]
    ADD C
    LD C, A
    LD A, [wPX]
    LD B, A
    CALL blocked
    JR Z, .no_down
    LD A, C
    LD [wPY], A
    CALL stepped
.no_down:

    ; --- the sprite: tiles 4/5 or 6/7, swapping every 8 steps ---
    CALL oam_begin
    LD A, [wAnim]
    AND 8
    RRCA
    RRCA                        ; 0 or 2
    ADD 4
    LD D, A
    LD A, [wPX]
    LD B, A
    LD A, [wPY]
    LD C, A
    LD A, [wFlags]
    LD E, A
    CALL oam_add
    CALL oam_end
    JP MainLoop                 ; (the loop is too long for a relative jump)

stepped:
    LD HL, wAnim
    INC [HL]
    RET

; --- Is the player's box (8 wide, 16 tall) with its top-left at B = x, C = y on a wall? ---
; Z set: blocked.  Z clear: free.  Six points are enough: the four corners and the middle
; of each side, because no tile is larger than the box.
blocked:
    LD D, B
    LD E, C
    CALL wall_at
    RET Z
    LD A, B
    ADD 7
    LD D, A
    LD E, C
    CALL wall_at
    RET Z
    LD D, B
    LD A, C
    ADD 8
    LD E, A
    CALL wall_at
    RET Z
    LD A, B
    ADD 7
    LD D, A
    LD A, C
    ADD 8
    LD E, A
    CALL wall_at
    RET Z
    LD D, B
    LD A, C
    ADD 15
    LD E, A
    CALL wall_at
    RET Z
    LD A, B
    ADD 7
    LD D, A
    LD A, C
    ADD 15
    LD E, A
    ; fall through: the answer for the last point is the answer for all

; --- Is the map square under pixel (D, E) a wall?  Z set if so.  Keeps BC. ---
wall_at:
    PUSH BC
    LD A, D
    SRL A
    SRL A
    SRL A
    LD B, A                     ; column = x / 8
    LD A, E
    SRL A
    SRL A
    SRL A
    LD C, A                     ; row = y / 8
    CALL shadow_addr            ; HL = that square in the shadow copy of the map
    LD A, [HL]
    CP TILE_WALL
    POP BC                      ; (POP does not change the flags)
    RET

WalkerTiles:
    ; Tile 0: blank
    DB $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
    ; Tile 1: checkerboard floor (colour 1)
    DB $AA,$00, $55,$00, $AA,$00, $55,$00, $AA,$00, $55,$00, $AA,$00, $55,$00
    ; Tile 2: wall
    DB $FF,$FF, $7E,$FF, $7E,$FF, $7E,$FF, $FF,$FF, $E7,$FF, $E7,$FF, $E7,$FF
    ; Tile 3: unused
    DB $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
    ; Tiles 4 and 5: the player, standing (head, then body and legs together)
    DB $3C,$3C, $7E,$7E, $7E,$7E, $7E,$5A, $7F,$7F, $7E,$7E, $3C,$3C, $18,$18
    DB $3C,$3C, $7E,$7E, $FF,$FF, $FF,$FF, $7E,$7E, $66,$66, $66,$66, $E7,$E7
    ; Tiles 6 and 7: the player mid-stride (legs apart)
    DB $3C,$3C, $7E,$7E, $7E,$7E, $7E,$5A, $7F,$7F, $7E,$7E, $3C,$3C, $18,$18
    DB $3C,$3C, $7E,$7E, $FF,$FF, $FF,$FF, $7E,$7E, $C3,$C3, $81,$81, $C3,$C3
WalkerTilesEnd:

INCLUDE "gfx.asm"
INCLUDE "tilemap.asm"
INCLUDE "oam.asm"
INCLUDE "vblank.asm"
INCLUDE "joypad.asm"
