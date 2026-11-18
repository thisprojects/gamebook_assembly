; =============================================================
; fast.asm - quick ways to move bytes and find addresses (Chapter 10)
; =============================================================
; VBlank lasts about 1,100 machine cycles, so every cycle counts when the
; screen has to be updated in a hurry.  A plain copy loop spends 13
; cycles per byte.  These routines do better:
;
;   copy_unrolled   HL = source, DE = destination, B = 16-byte blocks   (6 cycles/byte)
;   copy_stack      HL = source, DE = destination, B = 16-byte blocks   (4.5 cycles/byte)
;   fill_stack      HL = address just past the end, D = 16-byte blocks, A = value  (2 cycles/byte)
;   map_addr_fast   B = column (0-31), C = row (0-31) -> HL = map address
;
; The two stack routines borrow the stack pointer, so they switch
; interrupts off (DI) and leave them off: the caller turns them back on.

SECTION "FastVars", WRAM0
wSavedSP: DS 2

SECTION "FastRoutines", ROM0

copy_unrolled:
.block:
REPT 16
    LD A, [HL+]
    LD [DE], A
    INC DE
ENDR
    DEC B
    JR NZ, .block
    RET

; Reading with POP moves two bytes in one 3-cycle instruction.
copy_stack:
    DI
    LD [wSavedSP], SP
    LD SP, HL               ; the stack pointer now walks along the source
    LD H, D
    LD L, E                 ; HL = destination
.block:
REPT 8
    POP DE                  ; 2 bytes from the source in 3 cycles
    LD A, E
    LD [HL+], A
    LD A, D
    LD [HL+], A
ENDR
    DEC B
    JR NZ, .block
    JR restore_sp

; Writing with PUSH stores two bytes in one 4-cycle instruction, working
; downwards from the end of the area.
fill_stack:
    DI
    LD [wSavedSP], SP
    LD SP, HL
    LD B, A
    LD C, A
.block:
REPT 8
    PUSH BC
ENDR
    DEC D
    JR NZ, .block
restore_sp:
    LD A, [wSavedSP]
    LD L, A
    LD A, [wSavedSP + 1]
    LD H, A
    LD SP, HL
    RET

; row * 32 without a loop: rotating a 5-bit row number right three times
; leaves row / 8 in the low two bits and (row mod 8) * 32 in the top three.
map_addr_fast:
    LD A, C
    RRCA
    RRCA
    RRCA
    LD L, A
    AND %00000011
    ADD HIGH(VRAM_MAP0)
    LD H, A
    LD A, L
    AND %11100000
    ADD B
    LD L, A
    RET

; --- end of fast.asm
