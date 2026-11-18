; =============================================================
; text.asm - text and fonts (Chapter 8)
; =============================================================
; The Game Boy has no built-in font, so text is just tiles that the
; program supplies.  text_init expands a 1-bit-per-pixel font into
; tiles $20-$7F, so that the tile number of a letter is its ASCII
; code, and then printing a string is nothing more than writing those
; numbers into the tile map.
;
;   text_init       load the font (LCD must be off) and target the background map
;   text_window     send later text to the window map ($9C00)
;   text_background send later text to the background map ($9800)
;   print_at        B = column, C = row: move the cursor
;   print_char      A = character
;   print_string    HL = zero-terminated string
;   print_number    A = 0-255, printed as three digits
;
; Every write waits until the LCD is not using VRAM, so the printing
; routines are safe with the LCD on or off.

SECTION "TextVars", WRAM0
wCursor:  DS 2          ; map address where the next character goes
wTextMap: DS 2          ; base address of the map being written ($9800 or $9C00)

SECTION "TextRoutines", ROM0

text_init:
    LD HL, FontData
    LD DE, VRAM_TILES + $20 * 16
    LD BC, FontDataEnd - FontData
.expand:
    LD A, [HL+]             ; one row of 8 pixels, 1 bit each
    LD [DE], A              ; the same byte in both bit-planes ...
    INC DE
    LD [DE], A              ; ... makes every set pixel colour 3
    INC DE
    DEC BC
    LD A, B
    OR C
    JR NZ, .expand
text_background:
    LD HL, VRAM_MAP0
    JR set_text_map
text_window:
    LD HL, VRAM_MAP1
set_text_map:
    LD A, L
    LD [wTextMap], A
    LD A, H
    LD [wTextMap + 1], A
    RET

print_at:
    LD H, 0
    LD L, C
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL              ; row * 32
    LD E, B
    LD D, 0
    ADD HL, DE
    LD A, [wTextMap]
    LD E, A
    LD A, [wTextMap + 1]
    LD D, A
    ADD HL, DE
    LD A, L
    LD [wCursor], A
    LD A, H
    LD [wCursor + 1], A
    RET

print_char:
    LD E, A
    LD A, [wCursor]
    LD L, A
    LD A, [wCursor + 1]
    LD H, A
.wait:
    LDH A, [rSTAT]
    AND STATF_BUSY          ; mode 3 locks VRAM (2 and 3 lock OAM); wait for 0 or 1
    JR NZ, .wait
    LD [HL], E
    INC HL
    LD A, L
    LD [wCursor], A
    LD A, H
    LD [wCursor + 1], A
    RET

print_string:
    LD A, [HL+]
    OR A
    RET Z
    PUSH HL
    CALL print_char
    POP HL
    JR print_string

print_number:
    LD C, A
    LD B, 100
    CALL .digit
    LD B, 10
    CALL .digit
    LD B, 1
.digit:
    LD D, '0'               ; count how many times B fits into C
.sub:
    LD A, C
    CP B
    JR C, .out
    SUB B
    LD C, A
    INC D
    JR .sub
.out:
    LD A, D
    JP print_char

SECTION "Font", ROM0
INCLUDE "font.inc"
