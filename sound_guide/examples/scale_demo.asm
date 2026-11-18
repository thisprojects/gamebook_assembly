; scale_demo.asm - Chapter 2: notes from a table
; Plays the C major scale on channel 1, one note every 24 frames, and prints the
; name of each note.  The pitch values come from NoteTable in sound.asm.
SECTION "ScaleVars", WRAM0
wIndex: DS 1                    ; which note of the scale is next

INCLUDE "boot.inc"
INCLUDE "notes.inc"

    CALL screen_init
    CALL sound_init
    LD B, 2
    LD C, 2
    LD HL, Title
    CALL show_text

    LD A, DUTY_50
    LDH [rNR11], A
    XOR A
    LD [wIndex], A
    CALL frame_init
    EI

NextNote:
    LD A, [wIndex]
    LD E, A
    LD D, 0
    LD HL, Scale
    ADD HL, DE
    LD A, [HL]                  ; A = the note number
    PUSH AF
    LD B, 2
    LD C, 5
    CALL print_at
    POP AF
    PUSH AF
    CALL print_note             ; show its name
    POP AF
    CALL note_freq              ; DE = its pitch value
    LD A, $A2
    LDH [rNR12], A              ; volume 10, fading by one step every 2/64 s
    CALL play_ch1

    LD B, 24
.wait:
    CALL wait_frame
    DEC B
    JR NZ, .wait

    LD A, [wIndex]
    INC A
    CP 8
    JR NZ, .store
    XOR A                       ; after the eighth note, start the scale again
.store:
    LD [wIndex], A
    JR NextNote

Title: DB "C major scale", 0
Scale: DB C4, D4, E4, F4, G4, A4, B4, C5

INCLUDE "gfx.asm"
INCLUDE "text.asm"
INCLUDE "screen.asm"
INCLUDE "frame.asm"
INCLUDE "sound.asm"
