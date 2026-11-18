; instrument_demo.asm - Chapter 11: play it yourself
; Each of the eight buttons plays a note of the C major scale on channel 1, the moment it is
; pressed (the "newly pressed" byte from read_joypad: holding a button does not repeat it).
INCLUDE "boot.inc"
INCLUDE "notes.inc"

    CALL screen_init
    CALL sound_init
    LD B, 2
    LD C, 2
    LD HL, Title
    CALL show_text
    LD B, 1
    LD C, 4
    LD HL, Keys1
    CALL show_text
    LD B, 1
    LD C, 5
    LD HL, Keys2
    CALL show_text
    LD B, 2
    LD C, 7
    LD HL, Playing
    CALL show_text

    LD A, DUTY_50
    LDH [rNR11], A
    LD A, $C3
    LDH [rNR12], A              ; volume 12, fading out slowly
    XOR A
    LD [wJoy], A
    CALL frame_init
    EI

MainLoop:
    CALL wait_frame
    CALL read_joypad            ; once per frame, straight after the frame begins
    LD A, [wJoyNew]
    OR A
    JR Z, MainLoop              ; no new button this frame

    LD B, 0                     ; which button?  Find the lowest bit that is set.
.find:
    SRL A
    JR C, .found
    INC B
    JR .find
.found:
    LD HL, Notes
    LD E, B
    LD D, 0
    ADD HL, DE
    LD A, [HL]                  ; the note for that button
    PUSH AF
    LD B, 10
    LD C, 7
    CALL print_at
    POP AF
    PUSH AF
    CALL print_note             ; show its name
    POP AF
    CALL note_freq
    CALL play_ch1
    JR MainLoop

Title:   DB "Instrument", 0
Keys1:   DB "R:C L:D U:E D:F", 0
Keys2:   DB "A:G B:A Sl:B St:C", 0
Playing: DB "Playing", 0

; In the order of the bits in wJoy: A, B, Select, Start, Right, Left, Up, Down
Notes: DB G5, A5, B5, C6, C5, D5, E5, F5

INCLUDE "gfx.asm"
INCLUDE "text.asm"
INCLUDE "screen.asm"
INCLUDE "frame.asm"
INCLUDE "sound.asm"
INCLUDE "joypad.asm"
