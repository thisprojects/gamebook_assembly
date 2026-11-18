; =============================================================
; hardware.inc - Game Boy hardware register names
; =============================================================
; The Game Boy has no ROM routines and no IN/OUT instructions.
; Everything - screen, sound, buttons - is controlled by reading and
; writing memory addresses in the range $FF00-$FFFF.  These names
; just make the numbers readable.  Use them with LDH.

DEF rP1    EQU $FF00      ; Joypad
DEF rDIV   EQU $FF04      ; Divider (counts up all the time)
DEF rIF    EQU $FF0F      ; Interrupt flags (which interrupts are waiting)

; --- Sound: channel 1 (square wave with frequency sweep) ---
DEF rNR10  EQU $FF10      ; Sweep: time, direction, shift
DEF rNR11  EQU $FF11      ; Duty cycle (bits 7-6) and length (bits 5-0)
DEF rNR12  EQU $FF12      ; Volume envelope: start volume, direction, step time
DEF rNR13  EQU $FF13      ; Pitch, low 8 bits
DEF rNR14  EQU $FF14      ; Bit 7 = start, bit 6 = use length, bits 2-0 = pitch high bits

; --- Sound: channel 2 (square wave) ---
DEF rNR21  EQU $FF16      ; Duty cycle and length
DEF rNR22  EQU $FF17      ; Volume envelope
DEF rNR23  EQU $FF18      ; Pitch, low 8 bits
DEF rNR24  EQU $FF19      ; Start, use length, pitch high bits

; --- Sound: channel 3 (programmable wave) ---
DEF rNR30  EQU $FF1A      ; Bit 7 = channel on (the "DAC")
DEF rNR31  EQU $FF1B      ; Length (8 bits)
DEF rNR32  EQU $FF1C      ; Output level (bits 6-5)
DEF rNR33  EQU $FF1D      ; Pitch, low 8 bits
DEF rNR34  EQU $FF1E      ; Start, use length, pitch high bits
DEF rWAVE  EQU $FF30      ; Wave RAM: 16 bytes = 32 four-bit samples ($FF30-$FF3F)

; --- Sound: channel 4 (noise) ---
DEF rNR41  EQU $FF20      ; Length (bits 5-0)
DEF rNR42  EQU $FF21      ; Volume envelope
DEF rNR43  EQU $FF22      ; Noise: clock shift, width, divisor
DEF rNR44  EQU $FF23      ; Start, use length

; --- Sound: master controls ---
DEF rNR50  EQU $FF24      ; Master volume, left and right
DEF rNR51  EQU $FF25      ; Which channels go to which speaker
DEF rNR52  EQU $FF26      ; Bit 7 = sound on; bits 3-0 = channel 4-1 is playing (read only)

; --- Screen (used by the small on-screen displays in the examples) ---
DEF rLCDC  EQU $FF40      ; LCD control
DEF rSTAT  EQU $FF41      ; LCD status
DEF rSCY   EQU $FF42      ; Background scroll Y
DEF rSCX   EQU $FF43      ; Background scroll X
DEF rLY    EQU $FF44      ; Current scanline (0-153)
DEF rBGP   EQU $FF47      ; Background palette (shades)
DEF rOBP0  EQU $FF48      ; Sprite palette 0
DEF rOBP1  EQU $FF49      ; Sprite palette 1
DEF rIE    EQU $FFFF      ; Interrupt enable

; --- Sound register bits ---
DEF NRX4_START    EQU %10000000   ; NRx4: restart the channel
DEF NRX4_LENGTH   EQU %01000000   ; NRx4: stop when the length runs out
DEF DUTY_12       EQU %00000000   ; NRx1: pulse is high 1/8 of the time
DEF DUTY_25       EQU %01000000   ; NRx1: 2/8
DEF DUTY_50       EQU %10000000   ; NRx1: 4/8
DEF DUTY_75       EQU %11000000   ; NRx1: 6/8
DEF ENV_DOWN      EQU %00000000   ; NRx2: volume fades out
DEF ENV_UP        EQU %00001000   ; NRx2: volume swells
DEF WAVE_ON       EQU %10000000   ; NR30: channel 3 on
DEF WAVE_FULL     EQU %00100000   ; NR32: full volume
DEF WAVE_HALF     EQU %01000000   ; NR32: half volume
DEF WAVE_QUARTER  EQU %01100000   ; NR32: quarter volume
DEF NOISE_7BIT    EQU %00001000   ; NR43: short, buzzy noise (else long, hissy)
DEF SWEEP_UP      EQU %00000000   ; NR10: pitch rises
DEF SWEEP_DOWN    EQU %00001000   ; NR10: pitch falls

; --- rLCDC bits ---
DEF LCDCF_ON      EQU %10000000   ; LCD on
DEF LCDCF_BG8000  EQU %00010000   ; Background/window tiles come from $8000 (else $8800 signed)
DEF LCDCF_OBJON   EQU %00000010   ; Sprites on
DEF LCDCF_BGON    EQU %00000001   ; Background on

; --- rSTAT bits ---
DEF STATF_BUSY    EQU %00000010   ; Set in modes 2 and 3: VRAM/OAM may be unavailable

; --- rIE / rIF bits ---
DEF IEF_VBLANK    EQU %00000001

; --- Joypad bits (as returned by read_joypad: 1 = pressed) ---
; The same values as the standard gbdev hardware.inc: buttons in the low nibble, direction pad in the high one.
DEF PADF_A        EQU %00000001
DEF PADF_B        EQU %00000010
DEF PADF_SELECT   EQU %00000100
DEF PADF_START    EQU %00001000
DEF PADF_RIGHT    EQU %00010000
DEF PADF_LEFT     EQU %00100000
DEF PADF_UP       EQU %01000000
DEF PADF_DOWN     EQU %10000000

; --- Memory areas ---
DEF VRAM_TILES    EQU $8000       ; 256 tiles of 16 bytes
DEF VRAM_MAP0     EQU $9800       ; first 32x32 tile map
DEF VRAM_MAP1     EQU $9C00       ; second 32x32 tile map (text.asm can write to either)

; --- The standard LCDC setting used by the examples ---
DEF LCDC_NORMAL   EQU LCDCF_ON | LCDCF_BG8000 | LCDCF_OBJON | LCDCF_BGON
