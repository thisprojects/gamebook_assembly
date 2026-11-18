; noise_demo.asm - Chapter 8: the noise channel
; Five sounds from one channel: a kick, a snare, a hi-hat, an explosion and a buzz.  Each is
; just two bytes: the envelope (NR42) and the noise setting (NR43).
SECTION "NoiseVars", WRAM0
wIndex: DS 1

INCLUDE "boot.inc"

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

NextSound:
    LD A, [wIndex]
    ADD A                       ; two bytes per sound
    LD E, A
    LD D, 0
    LD HL, Sounds
    ADD HL, DE
    LD A, [HL+]
    LDH [rNR42], A
    LD A, [HL]
    LDH [rNR43], A
    LD A, NRX4_START
    LDH [rNR44], A              ; start it

    LD A, [wIndex]              ; labels are eight bytes each
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

    LD B, 60
.wait:
    CALL wait_frame
    DEC B
    JR NZ, .wait

    LD A, [wIndex]
    INC A
    CP 5
    JR NZ, .store
    XOR A
.store:
    LD [wIndex], A
    JR NextSound

Title: DB "Noise channel", 0
; NR42 = start volume (high 4 bits) | direction (bit 3) | step time (low 3 bits)
; NR43 = shift (high 4 bits) | width (bit 3: 1 = short, buzzy) | divisor (low 3 bits)
Sounds:
    DB $F2, $63                 ; kick:      low rumble that fades quickly
    DB $C1, $33                 ; snare:     mid-pitched crack
    DB $71, $11                 ; hi-hat:    high, very short tick
    DB $F7, $67                 ; explosion: low, long fade
    DB $F2, $2B                 ; buzz:      the short 7-bit pattern: a pitched rasp
Labels: DB "kick   ", 0, "snare  ", 0, "hi-hat ", 0, "explode", 0, "buzz   ", 0

INCLUDE "gfx.asm"
INCLUDE "text.asm"
INCLUDE "screen.asm"
INCLUDE "frame.asm"
INCLUDE "sound.asm"
