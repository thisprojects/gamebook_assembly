; duty_demo.asm - Chapter 3: the duty cycle of a square wave
; The same note (A4, 440 Hz) is played four times on channel 1, once with each duty
; cycle.  The pitch never changes: only the character of the sound does.
SECTION "DutyVars", WRAM0
wIndex: DS 1

INCLUDE "boot.inc"
INCLUDE "notes.inc"

    CALL screen_init
    CALL sound_init
    LD B, 2
    LD C, 2
    LD HL, Title
    CALL show_text
    XOR A
    LD [wIndex], A
    CALL frame_init
    EI

NextDuty:
    LD A, [wIndex]
    LD E, A
    LD D, 0
    LD HL, Duties
    ADD HL, DE
    LD A, [HL]
    LDH [rNR11], A              ; the duty cycle is the top two bits of NR11
    LD A, $C0
    LDH [rNR12], A              ; volume 12, steady
    LD A, A4
    CALL note_freq
    CALL play_ch1

    LD A, [wIndex]              ; the label: six characters each, so the address is label + 6 * index
    LD L, A
    LD H, 0
    LD D, H
    LD E, L
    ADD HL, HL                  ; 2 * index
    ADD HL, DE                  ; 3 * index
    ADD HL, HL                  ; 6 * index
    LD DE, Labels
    ADD HL, DE
    LD B, 2
    LD C, 5
    PUSH HL
    CALL print_at
    POP HL
    CALL print_string

    LD B, 45
.wait:
    CALL wait_frame
    DEC B
    JR NZ, .wait

    LD A, [wIndex]
    INC A
    AND 3                       ; 0, 1, 2, 3, 0, 1, ...
    LD [wIndex], A
    JR NextDuty

Title: DB "Duty cycle", 0
Duties: DB DUTY_12, DUTY_25, DUTY_50, DUTY_75
Labels: DB "12.5%", 0, "25%  ", 0, "50%  ", 0, "75%  ", 0

INCLUDE "gfx.asm"
INCLUDE "text.asm"
INCLUDE "screen.asm"
INCLUDE "frame.asm"
INCLUDE "sound.asm"
