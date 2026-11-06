INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]
    NOP
    JP Start
    DS $150 - @, 0       ; Room for the cartridge header (rgbfix fills it in)

SECTION "Main", ROM0[$150]
Start:
    LD A, IEF_VBLANK
    LDH [rIE], A         ; Let VBlank wake HALT

    ; Switch the sound hardware on
    LD A, $80
    LDH [rNR52], A       ; Master sound on
    LD A, $77
    LDH [rNR50], A       ; Full volume, left and right
    LD A, $FF
    LDH [rNR51], A       ; Send every channel to both speakers

    ; Play a beep on channel 1
    LD A, $80
    LDH [rNR11], A       ; 50% square wave
    LD A, $F3
    LDH [rNR12], A       ; Start at full volume, fade out slowly
    LD A, $C0
    LDH [rNR13], A       ; pitch, low 8 bits (higher value = higher pitch)
    LD A, $87
    LDH [rNR14], A       ; bit 7 = start the sound, bits 0-2 = pitch high bits

    ; Let it play for ~1/2 second (30 frames)
    LD B, 30
beep_wait:
    XOR A
    LDH [rIF], A
    HALT
    NOP
    DEC B
    JR NZ, beep_wait

Done:
    HALT                 ; Nothing left to do: sleep forever
    NOP
    JR Done
