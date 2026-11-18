; flicker_demo.asm - Chapter 6: more than ten sprites on a line
; Fourteen sprites share one scanline, but the hardware draws only ten per line.
; Normally the first ten in the sprite table win.  Press A to switch rotation on
; or off: when it is on, each frame the table starts one sprite further along, so
; every sprite is drawn on most frames and the loss shows as a flicker, not as
; sprites that are never there.
DEF SPRITES EQU 14

SECTION "FlickerVars", WRAM0
wOffset: DS 1                   ; which sprite goes first in the table this frame
wRotate: DS 1                   ; 1 = rotate the table order every frame
wSlot:   DS 1
wLeft:   DS 1

INCLUDE "boot.inc"

    CALL lcd_off
    LD A, %11100100
    CALL set_palette
    LD HL, BlockTile
    LD DE, VRAM_TILES + 16
    LD BC, 16
    CALL copy_bytes
    XOR A
    CALL fill_map
    XOR A
    LDH [rSCX], A
    LDH [rSCY], A
    LD [wOffset], A
    LD [wJoy], A
    LD A, 1
    LD [wRotate], A
    CALL oam_init
    CALL vblank_init
    CALL lcd_on
    EI

MainLoop:
    CALL wait_frame
    CALL read_joypad
    LD A, [wJoyNew]
    AND PADF_A
    JR Z, .keep
    LD A, [wRotate]
    XOR 1
    LD [wRotate], A
.keep:

    CALL oam_begin
    LD A, [wOffset]
    LD [wSlot], A
    LD A, SPRITES
    LD [wLeft], A
.add:
    LD A, [wSlot]               ; the sprite whose turn it is: slot number -> x position
    LD E, A
    LD D, 0
    LD HL, SlotX
    ADD HL, DE
    LD A, [HL]
    LD B, A
    LD C, 80
    LD D, 1
    LD E, 0
    CALL oam_add
    LD A, [wSlot]               ; next slot, wrapping round after the last
    INC A
    CP SPRITES
    JR C, .slot_ok
    XOR A
.slot_ok:
    LD [wSlot], A
    LD A, [wLeft]
    DEC A
    LD [wLeft], A
    JR NZ, .add
    CALL oam_end

    LD A, [wRotate]             ; start one sprite later next frame, if rotating
    OR A
    JR Z, MainLoop
    LD A, [wOffset]
    INC A
    CP SPRITES
    JR C, .off_ok
    XOR A
.off_ok:
    LD [wOffset], A
    JR MainLoop

SlotX:
FOR sx, SPRITES
    DB 8 + sx * 11
ENDR

BlockTile:
    DB $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF, $FF,$FF

INCLUDE "gfx.asm"
INCLUDE "oam.asm"
INCLUDE "vblank.asm"
INCLUDE "joypad.asm"
