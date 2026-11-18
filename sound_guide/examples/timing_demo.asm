; timing_demo.asm - Chapter 9: keeping time with frames
; A metronome.  One beat is 30 frames, so (at 60 frames a second) the tempo is 120 beats a
; minute.  Every fourth beat is the high note.  The program does nothing but count frames.
DEF BEAT_FRAMES EQU 30

SECTION "TimingVars", WRAM0
wCount: DS 1                    ; frames since the last beat
wBeat:  DS 1                    ; which beat of the bar: 0 to 3

INCLUDE "boot.inc"
INCLUDE "notes.inc"

    CALL screen_init
    CALL sound_init
    LD B, 2
    LD C, 2
    LD HL, Title
    CALL show_text
    LD B, 2
    LD C, 5
    LD HL, BeatLabel
    CALL show_text
    XOR A
    LD [wCount], A
    LD [wBeat], A
    CALL frame_init
    EI

MainLoop:
    CALL wait_frame             ; exactly one frame per time round the loop
    LD A, [wCount]
    OR A
    CALL Z, beat                ; the first frame of every beat
    LD A, [wCount]
    INC A
    CP BEAT_FRAMES
    JR NZ, .keep
    XOR A                       ; 30 frames have passed: back to the start of a beat
.keep:
    LD [wCount], A
    JR MainLoop

beat:
    LD B, 8                     ; show the beat number
    LD C, 5
    CALL print_at
    LD A, [wBeat]
    ADD '1'
    CALL print_char

    LD A, [wBeat]               ; beat 1 gets the high note
    OR A
    LD A, A4
    JR NZ, .note
    LD A, A5
.note:
    CALL note_freq
    LD A, DUTY_50 | 48          ; a short click: (64 - 48) / 256 s = 62 ms
    LDH [rNR21], A
    LD A, $B0
    LDH [rNR22], A
    LD A, E
    LDH [rNR23], A
    LD A, D
    OR NRX4_START | NRX4_LENGTH
    LDH [rNR24], A

    LD A, [wBeat]
    INC A
    AND 3                       ; 0, 1, 2, 3, 0, ...
    LD [wBeat], A
    RET

Title: DB "Metronome  120 bpm", 0
BeatLabel: DB "Beat", 0

INCLUDE "gfx.asm"
INCLUDE "text.asm"
INCLUDE "screen.asm"
INCLUDE "frame.asm"
INCLUDE "sound.asm"
