; =============================================================
; cgb.asm - Game Boy Color extras (Chapter 10)
; =============================================================
;   hdma_copy   HL = source, DE = destination in VRAM, B = blocks of 16 bytes (1-128)
; The Game Boy Color can copy blocks of memory into VRAM by hardware.
; The copy starts at once and the CPU waits until it has finished.  Like any
; other VRAM write it must be done with the LCD off or during VBlank.
; The hardware ignores the low four bits of both addresses, so the source data
; must start on a multiple of 16 (use SECTION ..., ALIGN[4]).

SECTION "CGBRoutines", ROM0

hdma_copy:
    LD A, H
    LDH [rHDMA1], A         ; source address, high byte
    LD A, L
    AND $F0
    LDH [rHDMA2], A         ; source address, low byte (the low 4 bits are ignored)
    LD A, D
    AND $1F
    LDH [rHDMA3], A         ; destination: $8000 + (a 13-bit offset, in steps of 16)
    LD A, E
    AND $F0
    LDH [rHDMA4], A
    LD A, B
    DEC A                   ; length register holds blocks - 1; bit 7 clear = copy it all now
    LDH [rHDMA5], A
    RET

; --- end of cgb.asm
