; =============================================================
; frame.asm - counting frames (Chapter 9)
; =============================================================
; The sound hardware plays a note without any help, but somebody has to
; change the registers at the right moments.  The program's clock is the
; screen: once per frame (about 60 times a second) the LCD enters VBlank
; and raises an interrupt.  The handler below just notes that it happened.
;
;   frame_init    enable the VBlank interrupt (call before EI)
;   wait_frame    sleep until the next frame has started
;
; wTicks counts frames since frame_init (and wraps at 256).
; The LCD must be on, or no VBlank ever comes.

SECTION "FrameVectorTable", ROM0[$40]
    JP VBlankHandler

SECTION "FrameVars", WRAM0
wVBlank: DS 1                   ; set by the handler, cleared by wait_frame
wTicks:  DS 1                   ; frames elapsed

SECTION "FrameRoutines", ROM0

frame_init:
    XOR A
    LD [wVBlank], A
    LD [wTicks], A
    LDH [rIF], A
    LD A, IEF_VBLANK
    LDH [rIE], A
    RET

VBlankHandler:
    PUSH AF
    LD A, 1
    LD [wVBlank], A
    LD A, [wTicks]
    INC A
    LD [wTicks], A
    POP AF
    RETI

; HALT stops the CPU until an interrupt arrives, which saves power and makes the timing exact.
wait_frame:
.sleep:
    HALT
    NOP
    LD A, [wVBlank]
    OR A
    JR Z, .sleep
    XOR A
    LD [wVBlank], A
    RET

; --- end of frame.asm
