; wave_demo.asm - Chapter 7: the programmable wave channel
; Channel 3 plays whatever 32 samples are in wave RAM.  The same note (A3) is played with
; four different wave shapes: sine, triangle, sawtooth and a thin pulse.
SECTION "WaveVars", WRAM0
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

NextWave:
    LD A, [wIndex]              ; each wave is 16 bytes
    SWAP A
    LD E, A
    LD D, 0
    LD HL, Waves
    ADD HL, DE
    CALL wave_load              ; wave RAM <- 16 bytes; channel 3 on

    LD A, WAVE_FULL
    LDH [rNR32], A              ; output level: full
    LD A, A3 + 12               ; this channel sounds an octave lower than the square ones,
    CALL note_freq              ; so ask for the note an octave up
    CALL play_ch3

    LD A, [wIndex]              ; labels are nine bytes each (eight letters and the zero)
    LD E, A
    ADD A
    ADD A
    ADD A                       ; 8 * index
    ADD E                       ; 9 * index
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

    LD B, 75
.wait:
    CALL wait_frame
    DEC B
    JR NZ, .wait

    LD A, [wIndex]
    INC A
    AND 3
    LD [wIndex], A
    JR NextWave

Title: DB "Wave channel", 0
Labels: DB "sine    ", 0, "triangle", 0, "sawtooth", 0, "pulse   ", 0

; Each wave: 32 samples of 4 bits, two to a byte, the first sample in the high four bits.
Waves:
    DB $8A, $BC, $DE, $FF, $FF, $ED, $CB, $A8, $75, $43, $21, $00, $00, $12, $34, $57   ; sine
    DB $01, $23, $45, $67, $89, $AB, $CD, $EF, $FE, $DC, $BA, $98, $76, $54, $32, $10   ; triangle
    DB $00, $11, $22, $33, $44, $55, $66, $77, $88, $99, $AA, $BB, $CC, $DD, $EE, $FF   ; sawtooth
    DB $FF, $FF, $FF, $FF, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00   ; pulse: high for 8 of 32

INCLUDE "gfx.asm"
INCLUDE "text.asm"
INCLUDE "screen.asm"
INCLUDE "frame.asm"
INCLUDE "sound.asm"
