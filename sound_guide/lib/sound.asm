; =============================================================
; sound.asm - the basic sound routines (Chapters 1, 2 and 7)
; =============================================================
;   sound_init    switch the sound hardware on: full volume, every channel to both speakers
;   note_freq     A = note number (0 = C2 ... 71 = B7)  ->  DE = pitch value
;   play_ch1      DE = pitch value: start channel 1 on that pitch
;   play_ch2      DE = pitch value: start channel 2
;   play_ch3      DE = pitch value: start channel 3
;   wave_load     HL = 16 bytes: load them into the wave RAM of channel 3
;
; The pitch value is the 11-bit number the hardware wants: the
; frequency in Hz is 131072 / (2048 - value) for the square channels.
; The envelope (volume) and duty must be set before the channel is started.

SECTION "SoundRoutines", ROM0

sound_init:
    XOR A
    LDH [rNR52], A          ; Switch the sound chip off: this clears every sound register ...
    LD A, $80
    LDH [rNR52], A          ; ... and on again.  Do this before any other sound register: while it is off they ignore writes
    LD A, $77
    LDH [rNR50], A          ; Full volume, left and right
    LD A, $FF
    LDH [rNR51], A          ; Send every channel to both speakers
    RET

; --- DE = the pitch value of note A ---
note_freq:
    LD L, A
    LD H, 0
    ADD HL, HL              ; two bytes per note
    LD DE, NoteTable
    ADD HL, DE
    LD A, [HL+]
    LD E, A
    LD D, [HL]
    RET

; --- Start a note: low 8 bits to NRx3, then the high 3 bits with the start flag to NRx4 ---
play_ch1:
    LD A, E
    LDH [rNR13], A
    LD A, D
    OR NRX4_START
    LDH [rNR14], A
    RET

play_ch2:
    LD A, E
    LDH [rNR23], A
    LD A, D
    OR NRX4_START
    LDH [rNR24], A
    RET

play_ch3:
    LD A, E
    LDH [rNR33], A
    LD A, D
    OR NRX4_START
    LDH [rNR34], A
    RET

; --- Copy 16 bytes (32 samples of 4 bits) from HL into the wave RAM ---
; Channel 3 is switched off while the wave RAM is rewritten, then back on.
wave_load:
    XOR A
    LDH [rNR30], A          ; off
    LD DE, rWAVE
    LD B, 16
.copy:
    LD A, [HL+]
    LD [DE], A
    INC DE
    DEC B
    JR NZ, .copy
    LD A, WAVE_ON
    LDH [rNR30], A          ; on
    RET

; --- The pitch value of every note from C2 to B7, equal temperament, A4 = 440 Hz ---
; value = 2048 - 131072 / frequency, rounded to the nearest whole number
NoteTable:
    DW $02C, $09D, $107, $16B, $1C9, $223, $277, $2C7, $312, $358, $39B, $3DA    ; C2 - B2
    DW $416, $44E, $483, $4B5, $4E5, $511, $53B, $563, $589, $5AC, $5CE, $5ED    ; C3 - B3
    DW $60B, $627, $642, $65B, $672, $689, $69E, $6B2, $6C4, $6D6, $6E7, $6F7    ; C4 - B4
    DW $706, $714, $721, $72D, $739, $744, $74F, $759, $762, $76B, $773, $77B    ; C5 - B5
    DW $783, $78A, $790, $797, $79D, $7A2, $7A7, $7AC, $7B1, $7B6, $7BA, $7BE    ; C6 - B6
    DW $7C1, $7C5, $7C8, $7CB, $7CE, $7D1, $7D4, $7D6, $7D9, $7DB, $7DD, $7DF    ; C7 - B7

; --- end of sound.asm
