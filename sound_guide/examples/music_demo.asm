; music_demo.asm - Chapter 10: a four-channel song
; A looping eight-second song in A minor: lead (channel 1), arpeggio (channel 2), bass
; (channel 3) and drums (channel 4).  Press A to fire a sound effect on channel 1 while
; the other three keep playing.
SECTION "MusicDemoVars", WRAM0

INCLUDE "boot.inc"
INCLUDE "notes.inc"

    CALL screen_init
    CALL sound_init
    LD B, 2
    LD C, 2
    LD HL, Title
    CALL show_text
    LD B, 2
    LD C, 4
    LD HL, Help
    CALL show_text
    LD HL, BassWave
    CALL wave_load              ; the bass is a triangle wave
    XOR A
    LD [wJoy], A
    CALL frame_init
    LD HL, Song
    CALL music_play
    EI

MainLoop:
    CALL wait_frame
    CALL music_tick             ; one frame of music
    CALL read_joypad
    LD A, [wJoyNew]
    AND PADF_A
    CALL NZ, jump_effect
    JR MainLoop

; --- A rising "jump" on channel 1, which the music leaves alone for 20 frames ---
jump_effect:
    LD A, 20
    CALL sfx_hold
    LD A, $16
    LDH [rNR10], A              ; sweep up
    LD A, DUTY_50
    LDH [rNR11], A
    LD A, $F3
    LDH [rNR12], A
    LD DE, $500
    JP play_ch1

Title: DB "Four channels", 0
Help:  DB "A: sound effect", 0

; --- The song: four stream addresses, then four instrument bytes ---
Song:
    DW LeadStream, ArpStream, BassStream, DrumStream
    DB $A2                      ; channel 1: NR12 (start volume 10, fading)
    DB $62                      ; channel 2: NR22 (start volume 6, fading)
    DB WAVE_FULL                ; channel 3: NR32 (full volume)
    DB 0                        ; channel 4: not used (each drum has its own envelope)

; Four bars of 96 frames: A minor, F, C, G.
LeadStream:
    DB A4, N8, C5, N8, E5, N4, C5, N8, A4, N8, E4, N4
    DB F4, N8, A4, N8, C5, N4, A4, N8, F4, N8, C4, N4
    DB C5, N8, E5, N8, G5, N4, E5, N8, C5, N8, G4, N4
    DB G4, N8, B4, N8, D5, N4, B4, N8, G4, N8, D4, N4
    DB SONG_LOOP

ArpStream:
    REPT 4
    DB A3, N16, C4, N16, E4, N16, C4, N16
    ENDR
    REPT 4
    DB F3, N16, A3, N16, C4, N16, A3, N16
    ENDR
    REPT 4
    DB C4, N16, E4, N16, G4, N16, E4, N16
    ENDR
    REPT 4
    DB G3, N16, B3, N16, D4, N16, B3, N16
    ENDR
    DB SONG_LOOP

BassStream:
    DB A2, N4, A2, N4, E3, N4, A2, N4
    DB F2, N4, F2, N4, C3, N4, F2, N4
    DB C3, N4, C3, N4, G3, N4, C3, N4
    DB G2, N4, G2, N4, D3, N4, G2, N4
    DB SONG_LOOP

DrumStream:
    REPT 4
    DB DRUM_KICK, N8, DRUM_HAT, N8, DRUM_SNARE, N8, DRUM_HAT, N8
    DB DRUM_KICK, N8, DRUM_HAT, N8, DRUM_SNARE, N8, DRUM_HAT, N8
    ENDR
    DB SONG_LOOP

; A triangle: the sample values rise 0 to 15 and fall back (two samples in each byte)
BassWave:
    DB $01, $23, $45, $67, $89, $AB, $CD, $EF, $FE, $DC, $BA, $98, $76, $54, $32, $10

INCLUDE "gfx.asm"
INCLUDE "text.asm"
INCLUDE "screen.asm"
INCLUDE "frame.asm"
INCLUDE "sound.asm"
INCLUDE "joypad.asm"
INCLUDE "music.asm"
