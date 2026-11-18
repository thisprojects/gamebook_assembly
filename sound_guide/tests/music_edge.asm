; music_edge.asm - a test-only program: a song with a rest, a loop and three unused channels
SECTION "EdgeVars", WRAM0

INCLUDE "boot.inc"
INCLUDE "notes.inc"

    CALL screen_init
    CALL sound_init
    CALL frame_init
    LD HL, Song
    CALL music_play
    EI
MainLoop:
    CALL wait_frame
    CALL music_tick
    JR MainLoop

Song:
    DW Stream, 0, 0, 0
    DB $F0, 0, 0, 0             ; channel 1: full volume, steady (no fade)
Stream:
    DB A4, N4, REST, N4, A4, N4
    DB SONG_LOOP

INCLUDE "gfx.asm"
INCLUDE "text.asm"
INCLUDE "screen.asm"
INCLUDE "frame.asm"
INCLUDE "sound.asm"
INCLUDE "music.asm"
