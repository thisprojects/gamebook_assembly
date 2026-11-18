; =============================================================
; vblank.asm - the VBlank handler and the tile update queue (Chapter 9)
; =============================================================
; The screen can only be changed safely in the short VBlank period at
; the end of each frame.  The program therefore does its thinking at any
; time and *queues up* its changes; the VBlank interrupt handler then
; carries them out in one quick burst:
;
;   1. copy the shadow OAM to the real OAM (sprites)
;   2. write every queued tile into the map
;   3. tell the main program a new frame has started
;
;   vblank_init     enable the VBlank interrupt (call before EI)
;   wait_frame      sleep until the next frame has started
;   queue_tile      A = tile, B = column, C = row: change one map entry at VBlank
;   queue_number    A = 0-255, B = column, C = row: queue three digits
;
; wTicks counts frames since the program began.

DEF QUEUE_SIZE EQU 16           ; at most 16 queued changes per frame

SECTION "VBlankVectorTable", ROM0[$40]
    JP VBlankHandler

SECTION "VBlankVars", WRAM0
wVBlank:    DS 1                ; set by the handler, cleared by wait_frame
wTicks:     DS 1                ; frames elapsed (wraps at 256)
wQueueLen:  DS 1                ; number of queued entries
wQueue:     DS QUEUE_SIZE * 3   ; each entry: map address (2 bytes), tile
wQueueTile: DS 1
wSavedIE:   DS 1
wNumber:    DS 1

SECTION "VBlankRoutines", ROM0

vblank_init:
    XOR A
    LD [wVBlank], A
    LD [wTicks], A
    LD [wQueueLen], A
    LDH [rIF], A
    LD A, IEF_VBLANK
    LDH [rIE], A
    RET

VBlankHandler:
    PUSH AF
    PUSH BC
    PUSH DE
    PUSH HL
    CALL hOAMDMA            ; sprites
    CALL flush_queue        ; map changes
    LD A, 1
    LD [wVBlank], A
    LD HL, wTicks
    INC [HL]
    POP HL
    POP DE
    POP BC
    POP AF
    RETI

; Sleep until the handler says a frame has begun.  HALT stops the CPU until an
; interrupt arrives, which saves power and makes the timing exact.
wait_frame:
.sleep:
    HALT
    NOP
    LD A, [wVBlank]
    OR A
    JR Z, .sleep
    XOR A
    LD [wVBlank], A
    RET

queue_tile:
    LD [wQueueTile], A
    LDH A, [rIE]
    LD [wSavedIE], A        ; remember which interrupts were enabled...
    AND %11111110
    LDH [rIE], A            ; ...and switch VBlank off while we add to the queue (the
                            ; handler empties it).  A VBlank that arrives meanwhile
                            ; stays pending and runs the moment we put rIE back.
    LD A, [wQueueLen]
    CP QUEUE_SIZE
    JR NC, .full            ; queue full: drop the change
    CALL map_addr           ; HL = map address (destroys DE)
    LD A, [wQueueLen]
    LD E, A
    ADD A
    ADD E                   ; entry offset = length * 3
    LD E, A
    LD D, 0
    PUSH HL
    LD HL, wQueue
    ADD HL, DE
    LD D, H
    LD E, L                 ; DE = where this entry goes
    POP HL                  ; HL = map address
    LD A, L
    LD [DE], A
    INC DE
    LD A, H
    LD [DE], A
    INC DE
    LD A, [wQueueTile]
    LD [DE], A
    LD HL, wQueueLen
    INC [HL]
.full:
    LD A, [wSavedIE]
    LDH [rIE], A            ; exactly as it was: safe to call with interrupts on or off
    RET

; Three decimal digits, queued left to right
queue_number:
    LD [wNumber], A
    LD A, 100
    CALL queue_digit
    LD A, 10
    CALL queue_digit
    LD A, 1
queue_digit:                ; A = place value; B, C = where to put the digit
    LD E, A
    LD D, '0'
    LD A, [wNumber]
.sub:
    CP E
    JR C, .out
    SUB E
    INC D
    JR .sub
.out:
    LD [wNumber], A         ; the remainder, for the next digit
    LD A, D
    PUSH BC
    CALL queue_tile
    POP BC
    INC B
    RET

; Called by the VBlank handler: write every queued tile into the map
flush_queue:
    LD A, [wQueueLen]
    OR A
    RET Z
    LD B, A
    LD DE, wQueue
.next:
    LD A, [DE]
    LD L, A
    INC DE
    LD A, [DE]
    LD H, A
    INC DE
    LD A, [DE]
    INC DE
    LD [HL], A              ; safe: we are inside VBlank
    DEC B
    JR NZ, .next
    XOR A
    LD [wQueueLen], A
    RET

; --- end of vblank.asm
