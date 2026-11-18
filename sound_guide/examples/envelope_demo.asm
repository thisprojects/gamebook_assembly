; envelope_demo.asm - Chapter 4: volume envelopes
; The same note (A4) on channel 2, four times, with four different envelopes:
; a quick pluck, a slow fade, a swell that grows from silence, and a steady tone.
SECTION "EnvVars", WRAM0
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

NextEnvelope:
    LD A, [wIndex]
    LD E, A
    LD D, 0
    LD HL, Envelopes
    ADD HL, DE
    LD A, DUTY_50
    LDH [rNR21], A
    LD A, [HL]
    LDH [rNR22], A              ; the envelope
    LD A, A4
    CALL note_freq
    CALL play_ch2

    LD A, [wIndex]              ; labels are eight characters each
    ADD A
    ADD A
    ADD A
    LD E, A
    LD D, 0
    LD HL, Labels
    ADD HL, DE
    LD B, 2
    LD C, 5
    PUSH HL
    CALL print_at
    POP HL
    CALL print_string

    LD B, 120                   ; two seconds each: long enough to hear a slow fade
.wait:
    CALL wait_frame
    DEC B
    JR NZ, .wait

    LD A, [wIndex]
    INC A
    AND 3
    LD [wIndex], A
    JR NextEnvelope

Title: DB "Envelopes", 0
; start volume (high 4 bits) | direction (bit 3) | step time (low 3 bits)
Envelopes:
    DB $F1                      ; start at 15, fall, one step every 1/64 s
    DB $F7                      ; start at 15, fall, one step every 7/64 s
    DB $03 | ENV_UP | $00       ; start at 0, rise, one step every 3/64 s
    DB $C0                      ; start at 12, no envelope: steady
Labels: DB "pluck ", 0, 0, "fade  ", 0, 0, "swell ", 0, 0, "steady", 0, 0

INCLUDE "gfx.asm"
INCLUDE "text.asm"
INCLUDE "screen.asm"
INCLUDE "frame.asm"
INCLUDE "sound.asm"
