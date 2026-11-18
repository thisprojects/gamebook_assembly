; sfx_demo.asm - Chapter 5: short sound effects with the length counter
; A = coin (two notes on channel 2), B = blip (one short note on channel 1),
; START = bonk (a burst of noise on channel 4).  None of them needs the program to stop the
; sound: each one is given a length when it starts and the hardware switches it off.
SECTION "SfxVars", WRAM0
wCoin: DS 1                     ; frames until the second note of the coin (0 = none pending)

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
    LD HL, Help1
    CALL show_text
    LD B, 2
    LD C, 6
    LD HL, Help2
    CALL show_text
    LD B, 2
    LD C, 7
    LD HL, Help3
    CALL show_text
    XOR A
    LD [wCoin], A
    LD [wJoy], A
    CALL frame_init
    EI

MainLoop:
    CALL wait_frame
    CALL read_joypad

    LD A, [wCoin]               ; is the second note of a coin due?
    OR A
    JR Z, .no_coin
    DEC A
    LD [wCoin], A
    CALL Z, coin_second
.no_coin:
    LD A, [wJoyNew]
    AND PADF_A
    CALL NZ, coin
    LD A, [wJoyNew]
    AND PADF_B
    CALL NZ, blip
    LD A, [wJoyNew]
    AND PADF_START
    CALL NZ, bonk
    JR MainLoop

; --- Coin: B5, then E6 six frames later ---
coin:
    LD A, DUTY_50 | 40          ; length 40: the sound lasts (64 - 40) / 256 s = 94 ms
    LDH [rNR21], A
    LD A, $F0
    LDH [rNR22], A              ; full volume, no fade: the length counter ends it
    LD A, B5
    CALL note_freq
    CALL start_ch2_short
    LD A, 6
    LD [wCoin], A
    RET

coin_second:
    LD A, DUTY_50 | 24          ; a longer second note: (64 - 24) / 256 s = 156 ms
    LDH [rNR21], A
    LD A, $F3
    LDH [rNR22], A              ; and let it fade as it goes
    LD A, E6
    CALL note_freq
    ; (fall through)

; --- Start channel 2 on pitch DE, to stop by itself when its length runs out ---
start_ch2_short:
    LD A, E
    LDH [rNR23], A
    LD A, D
    OR NRX4_START | NRX4_LENGTH
    LDH [rNR24], A
    RET

; --- Blip: C6 for 31 ms on channel 1 ---
blip:
    XOR A
    LDH [rNR10], A              ; no sweep
    LD A, DUTY_25 | 56          ; (64 - 56) / 256 s = 31 ms
    LDH [rNR11], A
    LD A, $F0
    LDH [rNR12], A
    LD A, C6
    CALL note_freq
    LD A, E
    LDH [rNR13], A
    LD A, D
    OR NRX4_START | NRX4_LENGTH
    LDH [rNR14], A
    RET

; --- Bonk: 47 ms of low noise on channel 4 ---
bonk:
    LD A, 52                    ; (64 - 52) / 256 s = 47 ms
    LDH [rNR41], A
    LD A, $F0
    LDH [rNR42], A
    LD A, $64                   ; low-pitched noise (Chapter 8 explains this byte)
    LDH [rNR43], A
    LD A, NRX4_START | NRX4_LENGTH
    LDH [rNR44], A
    RET

Title: DB "Sound effects", 0
Help1: DB "A     coin", 0
Help2: DB "B     blip", 0
Help3: DB "START bonk", 0

INCLUDE "gfx.asm"
INCLUDE "text.asm"
INCLUDE "screen.asm"
INCLUDE "frame.asm"
INCLUDE "sound.asm"
INCLUDE "joypad.asm"
