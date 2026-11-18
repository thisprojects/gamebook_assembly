; beep_demo.asm - Chapter 1: switch the sound on and play one note
; Channel 1 plays a square wave at 2048 Hz for about a second, fading out.
INCLUDE "boot.inc"

    CALL screen_init
    LD B, 2
    LD C, 2
    LD HL, Title
    CALL show_text

    CALL sound_init

    LD A, DUTY_50
    LDH [rNR11], A              ; 50% square wave
    LD A, $F3
    LDH [rNR12], A              ; start at full volume, fade out slowly
    LD A, $C0
    LDH [rNR13], A              ; pitch, low 8 bits  ($7C0 = 1984)
    LD A, NRX4_START | $07
    LDH [rNR14], A              ; start the sound; the 3 low bits are the top of the pitch

Done:
    HALT                        ; the sound plays by itself: nothing left to do
    NOP
    JR Done

Title: DB "Channel 1: 2048 Hz", 0

INCLUDE "gfx.asm"
INCLUDE "text.asm"
INCLUDE "screen.asm"
INCLUDE "sound.asm"
