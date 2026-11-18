; =============================================================
; gfx.asm - basic screen routines (Chapters 1, 2 and 9)
; =============================================================
;   wait_vblank   wait for the start of the next VBlank period
;   lcd_off       turn the LCD off (waits for VBlank first)
;   lcd_on        turn the LCD on with the standard settings
;   copy_bytes    HL = source, DE = destination, BC = count
;   fill_bytes    HL = destination, BC = count, A = value
;   fill_map      A = tile: fill the whole 32x32 background map
;   map_addr      B = column, C = row  ->  HL = address in the map
;   set_tile      A = tile, B = column, C = row: write one map entry
;   set_palette   A = shades for rBGP, rOBP0 and rOBP1
; Everything here that touches VRAM expects the LCD to be off
; or the CPU to be inside VBlank.

SECTION "GfxRoutines", ROM0

; --- Wait until the LCD reaches line 144, the first line of VBlank ---
wait_vblank:
.leave:
    LDH A, [rLY]
    CP 144
    JR NC, .leave           ; Already in VBlank?  Wait for it to finish first
.enter:
    LDH A, [rLY]
    CP 144
    JR C, .enter            ; Now wait for the next one to begin
    RET

; --- Turn the LCD off.  This is only allowed during VBlank ---
lcd_off:
.wait:
    LDH A, [rLY]
    CP 144
    JR C, .wait
    XOR A
    LDH [rLCDC], A          ; With the LCD off, VRAM is open all the time
    RET

lcd_on:
    LD A, LCDC_NORMAL
    LDH [rLCDC], A
    RET

; --- Copy BC bytes from HL to DE ---
copy_bytes:
    LD A, [HL+]
    LD [DE], A
    INC DE
    DEC BC
    LD A, B
    OR C
    JR NZ, copy_bytes
    RET

; --- Fill BC bytes at HL with A ---
fill_bytes:
    LD D, A
.loop:
    LD A, D
    LD [HL+], A
    DEC BC
    LD A, B
    OR C
    JR NZ, .loop
    RET

; --- Fill the whole background map with tile A ---
fill_map:
    LD HL, VRAM_MAP0
    LD BC, 32 * 32
    JP fill_bytes

; --- HL = VRAM_MAP0 + row * 32 + column ---
map_addr:
    LD H, 0
    LD L, C
    ADD HL, HL              ; x2
    ADD HL, HL              ; x4
    ADD HL, HL              ; x8
    ADD HL, HL              ; x16
    ADD HL, HL              ; x32
    LD E, B
    LD D, 0
    ADD HL, DE
    LD DE, VRAM_MAP0
    ADD HL, DE
    RET

; --- Put tile A at column B, row C ---
set_tile:
    PUSH AF
    CALL map_addr
    POP AF
    LD [HL], A
    RET

; --- Use the same shades for background and sprites ---
set_palette:
    LDH [rBGP], A
    LDH [rOBP0], A
    LDH [rOBP1], A
    RET
