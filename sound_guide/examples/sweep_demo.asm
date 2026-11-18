; sweep_demo.asm - Chapter 6: the frequency sweep of channel 1
; Three effects, one after another, each played by the hardware sweep unit alone: after the
; note is started the program does not touch the pitch again.
SECTION "SweepVars", WRAM0
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

NextSweep:
    LD A, [wIndex]
    ADD A
    ADD A                       ; four bytes per effect
    LD E, A
    LD D, 0
    LD HL, Effects
    ADD HL, DE
    LD A, [HL+]
    LDH [rNR10], A              ; the sweep: time, direction, shift
    LD A, [HL+]
    LDH [rNR12], A              ; envelope
    LD A, [HL+]
    LD E, A
    LD D, [HL]                  ; DE = the pitch to start from
    LD A, DUTY_50
    LDH [rNR11], A
    CALL play_ch1

    LD A, [wIndex]              ; labels are six characters each
    ADD A
    LD L, A
    LD H, 0
    LD D, H
    LD E, L
    ADD HL, HL
    ADD HL, DE                  ; 6 * index
    LD DE, Labels
    ADD HL, DE
    LD B, 2
    LD C, 5
    PUSH HL
    CALL print_at
    POP HL
    CALL print_string

    LD B, 90
.wait:
    CALL wait_frame
    DEC B
    JR NZ, .wait

    LD A, [wIndex]
    INC A
    CP 3
    JR NZ, .store
    XOR A
.store:
    LD [wIndex], A
    JR NextSweep

Title: DB "Frequency sweep", 0
; NR10, NR12, pitch value (2 bytes)
;   NR10 = time (bits 6-4) | direction (bit 3: 1 = falling) | shift (bits 2-0)
Effects:
    DB $16, $F3, $00, $05       ; jump:  rises, a step every 7.8 ms, each adding 1/64 of the value
    DB $2D, $F3, $A0, $07       ; laser: falls, a step every 15.6 ms, each taking off 1/32
    DB $7F, $F7, $C0, $07       ; slide: falls slowly, a step every 54 ms, each taking off 1/128
Labels: DB "jump ", 0, "laser", 0, "slide", 0

INCLUDE "gfx.asm"
INCLUDE "text.asm"
INCLUDE "screen.asm"
INCLUDE "frame.asm"
INCLUDE "sound.asm"
