; =============================================================
; debug_output.asm - Debug Display Routines for the Game Boy
; =============================================================
; INCLUDE this file in your program (after your own code).
; It needs hardware.inc and font.inc.
;
; Call debug_init once at the start of your program to set up
; the screen.  Then use:
;
;   print_char    - Print a single character.  Input: A = char
;   print_string  - Print a null-terminated string.  Input: HL
;   print_number  - Print an 8-bit number (0-255).  Input: A
;   print_block   - Print a block of bytes.  Input: DE = address, BC = length
;   set_cursor    - Move the cursor.  Input: B = row (0-17), C = column (0-19)
;
; For a newline, just do: LD A, 13 / RST $10
; (RST $10 is wired up below to jump to print_char.)
;
; The screen is 20 characters wide and 18 rows high.  Text wraps at
; the end of a line, and wraps back to the top after the last row.
;
; Register use:  print_char keeps every register except AF.
;                print_number keeps BC.  Treat DE and HL as destroyed.
; =============================================================

SECTION "DebugVars", WRAM0
wCursorX: DS 1          ; Cursor column, 0-19
wCursorY: DS 1          ; Cursor row, 0-17

SECTION "RST10", ROM0[$10]
    JP print_char       ; RST $10 = print the character in A

SECTION "DebugOutput", ROM0

; --- Call once at program start to set up the screen ---
debug_init:
wait_for_vblank:
    LDH A, [rLY]
    CP 144
    JR C, wait_for_vblank   ; Wait until the LCD is in VBlank (LY >= 144)

    XOR A
    LDH [rLCDC], A          ; Turn the LCD off so we may write to VRAM freely

    LD A, %11100100         ; Palette: colour 0 = lightest ... colour 3 = darkest
    LDH [rBGP], A
    LDH [rOBP0], A
    XOR A
    LDH [rSCX], A           ; No scrolling
    LDH [rSCY], A

    ; Copy the font into VRAM, starting at tile $20 so that
    ; tile number = ASCII code.  Each font byte is one row of 8
    ; pixels; a Game Boy tile row is two bytes, so write it twice.
    LD HL, FontData
    LD DE, VRAM_TILES + $20 * 16
    LD BC, FontDataEnd - FontData
font_loop:
    LD A, [HL+]
    LD [DE], A
    INC DE
    LD [DE], A
    INC DE
    DEC BC
    LD A, B
    OR C
    JR NZ, font_loop

    ; Fill the 32x32 background map with spaces
    LD HL, VRAM_MAP
    LD BC, 32 * 32
clear_map:
    LD A, ' '
    LD [HL+], A
    DEC BC
    LD A, B
    OR C
    JR NZ, clear_map

    ; Hide every sprite (OAM contains random junk at power-on)
    LD HL, OAM_RAM
    LD B, 160
    XOR A
clear_oam:
    LD [HL+], A
    DEC B
    JR NZ, clear_oam

    XOR A
    LD [wCursorX], A        ; Cursor to the top left
    LD [wCursorY], A

    LD A, LCDCF_ON | LCDCF_BG8000 | LCDCF_BGON
    LDH [rLCDC], A          ; LCD back on
    RET

; --- Move the cursor: B = row, C = column ---
set_cursor:
    LD A, B
    LD [wCursorY], A
    LD A, C
    LD [wCursorX], A
    RET

; --- Print a single character in A (13 = newline) ---
print_char:
    PUSH BC
    PUSH DE
    PUSH HL
    CP 13
    JR Z, newline
    LD C, A                 ; C = the character

    ; HL = VRAM_MAP + row * 32 + column
    LD A, [wCursorY]
    LD L, A
    LD H, 0
    ADD HL, HL              ; x2
    ADD HL, HL              ; x4
    ADD HL, HL              ; x8
    ADD HL, HL              ; x16
    ADD HL, HL              ; x32
    LD DE, VRAM_MAP
    ADD HL, DE
    LD A, [wCursorX]
    LD E, A
    LD D, 0
    ADD HL, DE

wait_for_vram:
    LDH A, [rSTAT]          ; VRAM is locked while the LCD is drawing a line
    AND STATF_BUSY
    JR NZ, wait_for_vram
    LD [HL], C              ; Put the character on screen

    LD A, [wCursorX]
    INC A
    LD [wCursorX], A
    CP SCREEN_W
    JR C, print_done        ; Still room on this line

newline:
    XOR A
    LD [wCursorX], A        ; Back to column 0
    LD A, [wCursorY]
    INC A
    CP SCREEN_H
    JR C, store_row
    XOR A                   ; Past the bottom: wrap to the top
store_row:
    LD [wCursorY], A
print_done:
    POP HL
    POP DE
    POP BC
    RET

; --- Print null-terminated string at HL ---
print_string:
    LD A, [HL]
    OR A                    ; Check for null terminator
    RET Z                   ; Return if end of string
    RST $10                 ; Print character
    INC HL
    JR print_string

; --- Print BC bytes starting at DE (BC must not be 0) ---
print_block:
    LD A, [DE]
    RST $10
    INC DE
    DEC BC
    LD A, B
    OR C
    JR NZ, print_block
    RET

; --- Print 8-bit unsigned number in A (0-255) ---
print_number:
    PUSH BC
    LD B, A                 ; B = what is left of the number
    LD D, 0                 ; D = 1 once we have printed a digit
    LD C, 100
    CALL print_digit        ; Hundreds
    LD C, 10
    CALL print_digit        ; Tens
    LD A, B
    ADD A, '0'
    RST $10                 ; Units (always printed, so 0 prints as "0")
    POP BC
    RET

; B = remainder so far, C = 100 or 10, D = printed-a-digit flag
print_digit:
    LD E, 0                 ; E = how many times C goes into B
digit_loop:
    LD A, B
    CP C
    JR C, digit_done        ; B < C, so we have the digit
    SUB C
    LD B, A
    INC E
    JR digit_loop
digit_done:
    LD A, E
    OR D
    RET Z                   ; Leading zero: skip it
    LD D, 1
    LD A, E
    ADD A, '0'
    RST $10
    RET

INCLUDE "font.inc"

; =============================================================
; END OF DEBUG ROUTINES
; =============================================================
