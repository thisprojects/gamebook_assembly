; anim_demo.asm - Chapter 9: a frame loop driven by the VBlank interrupt
; A ball bounces round the screen while a frame counter ticks in the
; corner.  All the thinking happens in the main loop; the screen is
; only touched by the VBlank handler (sprites by DMA, the counter by
; the update queue).
IF !DEF(PROFILE)
    DEF PROFILE EQU 0           ; assemble with  rgbasm -D PROFILE=1  to see how long each frame's work takes
ENDC

SECTION "AnimVars", WRAM0
wBallX:  DS 1                   ; position in screen pixels of the ball's top-left corner
wBallY:  DS 1
wBallDX: DS 1                   ; velocity, +1 or -1 ($FF) pixels per frame
wBallDY: DS 1

INCLUDE "boot.inc"

    CALL lcd_off
    LD A, %11100100
    CALL set_palette
    LD A, $20
    CALL fill_map               ; blank (space) everywhere
    CALL text_init              ; digits for the counter
    LD HL, BallTile
    LD DE, VRAM_TILES + 1 * 16
    LD BC, 16
    CALL copy_bytes

    LD A, 40
    LD [wBallX], A
    LD A, 30
    LD [wBallY], A
    LD A, 1
    LD [wBallDX], A
    LD [wBallDY], A

    XOR A
    LDH [rSCX], A
    LDH [rSCY], A
    CALL oam_init
    CALL vblank_init
    CALL lcd_on
    EI

MainLoop:
    CALL wait_frame             ; sleeps until the handler has run
IF PROFILE
    LD A, %11111111
    LDH [rBGP], A               ; the whole screen goes black while we work...
ENDC

    ; --- move the ball, bouncing off the edges of the screen ---
    LD A, [wBallDX]
    LD B, A
    LD A, [wBallX]
    ADD B
    LD [wBallX], A
    CP 1                        ; left edge
    JR Z, .bounce_x
    CP SCREEN_W * 8 - 8         ; right edge
    JR NZ, .x_ok
.bounce_x:
    LD A, B
    CPL
    INC A
    LD [wBallDX], A
.x_ok:
    LD A, [wBallDY]
    LD B, A
    LD A, [wBallY]
    ADD B
    LD [wBallY], A
    CP 1                        ; top edge
    JR Z, .bounce_y
    CP SCREEN_H * 8 - 8         ; bottom edge
    JR NZ, .y_ok
.bounce_y:
    LD A, B
    CPL
    INC A
    LD [wBallDY], A
.y_ok:

    ; --- describe this frame's sprite ---
    CALL oam_begin
    LD A, [wBallX]
    LD B, A
    LD A, [wBallY]
    LD C, A
    LD D, 1
    LD E, 0
    CALL oam_add
    CALL oam_end

    ; --- queue the frame counter: three digits at the top left ---
    LD A, [wTicks]
    LD B, 1
    LD C, 0
    CALL queue_number

IF PROFILE
    LD A, %11100100
    LDH [rBGP], A               ; ... and goes back to normal when we are done: the black band shows the cost
ENDC
    JR MainLoop

BallTile:
    DB $3C,$3C, $7E,$42, $FF,$81, $FF,$81, $FF,$81, $FF,$81, $7E,$42, $3C,$3C

INCLUDE "gfx.asm"
INCLUDE "text.asm"
INCLUDE "oam.asm"
INCLUDE "vblank.asm"
