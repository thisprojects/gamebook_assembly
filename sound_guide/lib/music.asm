; =============================================================
; music.asm - a small music engine (Chapter 10)
; =============================================================
; A song is four streams of events, one per channel.  Once per frame
; the engine counts each channel's wait down; when it reaches zero it
; reads the next event: a note (or rest) and how many frames it lasts.
;
;   music_play    HL = song: start playing it from the beginning
;   music_stop    silence the music
;   music_tick    call once per frame, straight after wait_frame
;   sfx_hold      A = frames: keep the music off channel 1 for a while (a sound effect is using it)
;
; A song begins with four stream addresses (channel 1 to 4; 0 = unused),
; followed by four instrument bytes: the value written to NRx2 for
; channels 1, 2 and 4, and to NR32 for channel 3.  Each stream is
; pairs of bytes:  note, frames.   A rest is REST; SONG_LOOP goes back
; to the start.  On channel 4 the "note" picks a drum from DrumTable.

DEF CHANNELS EQU 4

SECTION "MusicVars", WRAM0
wMusicOn:    DS 1
wSfxTimer:   DS 1                   ; frames left before the music may use channel 1 again
wDuration:   DS 1                   ; scratch
wChanWait:   DS CHANNELS            ; frames left in the current event, per channel
wChanPtr:    DS CHANNELS * 2        ; where each channel is reading
wChanStart:  DS CHANNELS * 2        ; where each channel began (for looping)
wChanInstr:  DS CHANNELS            ; the instrument byte of each channel

SECTION "MusicRoutines", ROM0

; --- Begin a song: copy the header into RAM and make every channel read its first event next tick ---
music_play:
    LD B, 0
.channel:
    LD A, [HL+]
    LD E, A
    LD A, [HL+]
    LD D, A                     ; DE = this channel's stream
    OR E
    JR NZ, .used
    LD DE, EmptyStream          ; an unused channel just rests
.used:
    PUSH HL
    LD A, B
    ADD A
    LD C, A                     ; C = 2 * channel
    LD HL, wChanPtr
    CALL .store
    LD HL, wChanStart
    CALL .store
    POP HL
    INC B
    LD A, B
    CP CHANNELS
    JR NZ, .channel
    LD B, 0
    LD DE, wChanInstr
.instr:
    LD A, [HL+]
    LD [DE], A
    INC DE
    INC B
    LD A, B
    CP CHANNELS
    JR NZ, .instr
    XOR A
    LD [wSfxTimer], A
    LD HL, wChanWait
    LD B, CHANNELS
.clear:
    LD [HL+], A
    DEC B
    JR NZ, .clear
    LD A, $40
    LDH [rNR11], A              ; channel 1 plays a 25% pulse...
    LD A, $80
    LDH [rNR21], A              ; ...and channel 2 a 50% pulse
    LD A, WAVE_ON
    LDH [rNR30], A
    LD A, 1
    LD [wMusicOn], A
    RET
.store:                         ; [HL + C] = DE (two bytes)
    LD A, L
    ADD C
    LD L, A
    JR NC, .nocarry
    INC H
.nocarry:
    LD A, E
    LD [HL+], A
    LD [HL], D
    RET

music_stop:
    XOR A
    LD [wMusicOn], A
    LDH [rNR12], A
    LDH [rNR22], A
    LDH [rNR32], A
    LDH [rNR42], A
    RET

sfx_hold:
    LD [wSfxTimer], A
    RET

; --- One frame of music ---
music_tick:
    LD A, [wMusicOn]
    OR A
    RET Z
    LD A, [wSfxTimer]
    OR A
    JR Z, .go
    DEC A
    LD [wSfxTimer], A
.go:
    LD B, 0
.channel:
    CALL channel_tick
    INC B
    LD A, B
    CP CHANNELS
    JR NZ, .channel
    RET

; --- One frame for channel B ---
channel_tick:
    LD HL, wChanWait
    LD E, B
    LD D, 0
    ADD HL, DE
    LD A, [HL]
    OR A
    JR Z, .fetch                ; nothing left to wait for: time for the next event
    DEC A
    LD [HL], A
    RET NZ                      ; still waiting
.fetch:
    CALL get_ptr                ; HL = the next byte of this channel's stream
    LD A, [HL+]
    CP SONG_LOOP
    JR NZ, .event
    CALL rewind                 ; end of the stream: start again from the top
    CALL get_ptr
    LD A, [HL+]
.event:
    LD C, A                     ; C = note (or REST)
    LD A, [HL+]
    LD [wDuration], A           ; the event's length in frames
    CALL put_ptr                ; remember where we have got to
    LD HL, wChanWait
    LD E, B
    LD D, 0
    ADD HL, DE
    LD A, [wDuration]
    LD [HL], A
    LD A, C
    CP REST
    JR Z, silence               ; a rest: stop whatever is sounding on this channel
    LD A, B
    OR A
    JR NZ, play_event
    LD A, [wSfxTimer]           ; channel 1 belongs to a sound effect right now
    OR A
    RET NZ
    XOR A
    LDH [rNR10], A              ; the effect may have left a sweep or another duty behind: put them back
    LD A, $40
    LDH [rNR11], A

; --- Start note C on channel B ---
play_event:
    LD A, B
    CP 3
    JR Z, .drum
    LD A, B
    CP 2
    LD A, C
    JR NZ, .lookup
    ADD 12                      ; the wave channel sounds an octave lower, so ask for one higher
.lookup:
    CALL note_freq              ; DE = pitch value
    CALL nrx2_address           ; C = this channel's NRx2 register (the note is done with)
    LD HL, wChanInstr
    LD A, B
    ADD L
    LD L, A
    JR NC, .nocarry
    INC H
.nocarry:
    LD A, [HL]                  ; the channel's instrument
    LDH [C], A                  ; NRx2 (or NR32)
    INC C
    LD A, E
    LDH [C], A                  ; pitch, low 8 bits
    INC C
    LD A, D
    OR NRX4_START
    LDH [C], A                  ; pitch high bits + start
    RET
.drum:
    LD A, C
    ADD A                       ; two bytes per drum
    LD E, A
    LD D, 0
    LD HL, DrumTable
    ADD HL, DE
    LD A, [HL+]
    LDH [rNR42], A              ; the drum's envelope
    LD A, [HL]
    LDH [rNR43], A              ; the drum's noise setting
    LD A, NRX4_START
    LDH [rNR44], A
    RET

; --- Silence channel B.  A playing channel reads its envelope register only when it is started, so
; the way to a quiet note without a click is to write volume 0 ($08: output still on) and start the
; channel again.  (Writing 0 would switch the output off, which can click on a real console.)
; Channel 3 has no envelope: its volume register is muted instead, and that takes effect at once. ---
silence:
    LD A, B
    OR A
    JR NZ, .go
    LD A, [wSfxTimer]           ; channel 1 may be playing a sound effect: leave it alone
    OR A
    RET NZ
.go:
    CALL nrx2_address           ; C = the low byte of this channel's NRx2 address
    LD A, B
    CP 2
    LD A, ENV_UP                ; volume 0, rising, no step time: silent, output still on
    JR NZ, .write
    XOR A                       ; channel 3: volume 0 (muted)
    LDH [C], A
    RET
.write:
    LDH [C], A
    INC C
    INC C                       ; NRx4: the start register is two on from NRx2
    LD A, NRX4_START
    LDH [C], A                  ; start again, at volume 0
    RET

; --- C = $12 + 5 * channel B: the NRx2 registers are $FF12, $FF17, $FF1C and $FF21 ---
nrx2_address:
    LD A, B
    ADD A
    ADD A
    ADD B
    ADD $12
    LD C, A
    RET

; --- HL = the stream pointer of channel B ---
get_ptr:
    LD A, B
    ADD A
    LD E, A
    LD D, 0
    LD HL, wChanPtr
    ADD HL, DE
    LD A, [HL+]
    LD H, [HL]
    LD L, A
    RET

; --- Store HL as the stream pointer of channel B ---
put_ptr:
    LD A, B
    ADD A
    LD E, A
    LD D, 0
    PUSH HL
    LD HL, wChanPtr
    ADD HL, DE
    POP DE
    LD A, E
    LD [HL+], A
    LD [HL], D
    RET

; --- Copy channel B's start pointer into its stream pointer ---
rewind:
    LD A, B
    ADD A
    LD E, A
    LD D, 0
    LD HL, wChanStart
    ADD HL, DE
    LD A, [HL+]
    LD C, A
    LD A, [HL]
    LD HL, wChanPtr
    ADD HL, DE
    LD [HL], C
    INC HL
    LD [HL], A
    RET

; --- Three drums: NR42 (envelope) and NR43 (noise setting) for each ---
DrumTable:
    DB $F2, $63                 ; 0: kick     - low, short boom
    DB $C1, $33                 ; 1: snare    - mid-pitched crack
    DB $71, $11                 ; 2: hi-hat   - high, very short tick

EmptyStream:
    DB REST, 255, SONG_LOOP

; --- end of music.asm
