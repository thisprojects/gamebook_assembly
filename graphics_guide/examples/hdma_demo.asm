; hdma_demo.asm - Chapter 10: copying tiles with the Game Boy Color's DMA hardware
; Build with  rgbfix -c  (the Makefile does).  The same 1,024 bytes of tile data are
; copied twice, once by a CPU loop and once by the DMA hardware.
INCLUDE "boot.inc"

    CALL lcd_off

    LD A, $80                   ; palette 0: white, light, dark, black (grey ramp)
    LDH [rBCPS], A
    LD HL, GreyRamp
    LD B, 8
.ramp:
    LD A, [HL+]
    LDH [rBCPD], A
    DEC B
    JR NZ, .ramp

    ; 1. The CPU loop: 1,024 bytes (64 tiles) of data into tile memory.
    LD HL, TileData
    LD DE, VRAM_TILES + 64 * 16
    LD BC, 1024
    CALL copy_bytes

    ; 2. The same bytes with hardware DMA, straight into tiles 0-63.
    LD HL, TileData
    LD DE, VRAM_TILES
    LD B, 64                    ; 64 blocks of 16 bytes
    CALL hdma_copy              ; the CPU simply waits while the hardware does the copying

    LD HL, VRAM_MAP0            ; show tiles 0-63 as a block, 16 across
    XOR A
    LD C, 4
.row:
    LD B, 16
.col:
    LD [HL+], A
    INC A
    DEC B
    JR NZ, .col
    LD DE, 32 - 16
    ADD HL, DE
    DEC C
    JR NZ, .row

    XOR A
    LDH [rSCX], A
    LDH [rSCY], A
    CALL lcd_on
Done:
    HALT
    NOP
    JR Done

GreyRamp:
    DW $7FFF, $4210, $2108, $0000

; 64 tiles, each a different pattern.  The hardware ignores the low four bits of the
; source address, so the data must start on a multiple of 16: that is what ALIGN[4] does.
SECTION "TileDataAligned", ROM0, ALIGN[4]
TileData:
FOR tn, 64
    REPT 8
        DB tn * 4, tn * 3 + 1
    ENDR
ENDR

INCLUDE "gfx.asm"
INCLUDE "cgb.asm"
