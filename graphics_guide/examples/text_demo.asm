; text_demo.asm - Chapter 8: text, custom glyphs and a window text box
INCLUDE "boot.inc"

    CALL lcd_off
    LD A, %11100100
    CALL set_palette
    LD A, $20                   ; the space character is tile $20: clear both maps with it
    CALL fill_map
    LD HL, VRAM_MAP1
    LD BC, 32 * 32
    LD A, $20
    CALL fill_bytes

    CALL text_init              ; font -> tiles $20-$7F

    ; Our own glyphs go in the unused tiles below $20
    LD HL, Glyphs
    LD DE, VRAM_TILES + 1 * 16
    LD BC, GlyphsEnd - Glyphs
    CALL copy_bytes

    ; --- Text on the background ---
    LD B, 2
    LD C, 2
    CALL print_at
    LD HL, Title
    CALL print_string

    LD B, 2
    LD C, 4
    CALL print_at
    LD HL, ScoreLabel
    CALL print_string
    LD A, 42
    CALL print_number

    ; --- Our own glyphs are printed exactly like letters ---
    LD B, 2
    LD C, 6
    CALL print_at
    LD A, 1                     ; heart (print_char uses A, so load it again each time)
    CALL print_char
    LD A, 1
    CALL print_char
    LD A, 1
    CALL print_char
    LD A, 2                     ; arrow
    CALL print_char
    LD A, 3                     ; smiley
    CALL print_char

    ; --- A message box in the window layer, covering the bottom four rows ---
    CALL text_window
    LD B, 0
    LD C, 0
    CALL print_at
    LD A, 4                     ; frame tile across the top...
    LD B, SCREEN_W
.top:
    CALL print_char
    LD A, 4
    DEC B
    JR NZ, .top
    LD B, 1
    LD C, 3
    CALL print_at
    LD A, 4                     ; ...and across the bottom
    LD B, SCREEN_W - 2
.bottom:
    CALL print_char
    LD A, 4
    DEC B
    JR NZ, .bottom

    LD A, 7
    LDH [rWX], A
    LD A, 112                   ; window starts on row 14
    LDH [rWY], A
    XOR A
    LDH [rSCX], A
    LDH [rSCY], A
    LD A, LCDC_NORMAL | LCDCF_WINON | LCDCF_WIN9C00
    LDH [rLCDC], A

    ; --- Now type the message out one letter at a time, with the LCD running ---
    LD B, 2
    LD C, 1
    CALL print_at
    LD HL, Message
.type:
    LD A, [HL+]
    OR A
    JR Z, Done
    PUSH HL
    CALL print_char
    CALL wait_vblank            ; one letter every 2 frames
    CALL wait_vblank
    POP HL
    JR .type

Done:
    HALT
    NOP
    JR Done

Title:      DB "HELLO, GAME BOY!", 0
ScoreLabel: DB "SCORE ", 0
Message:    DB "TEXT IS JUST TILES.", 0

Glyphs:
    ; Tile 1: heart
    DB $00,$00, $66,$66, $FF,$FF, $FF,$FF, $7E,$7E, $3C,$3C, $18,$18, $00,$00
    ; Tile 2: arrow
    DB $00,$00, $10,$10, $08,$08, $FC,$FC, $08,$08, $10,$10, $00,$00, $00,$00
    ; Tile 3: smiley
    DB $3C,$3C, $42,$42, $A5,$A5, $81,$81, $A5,$A5, $99,$99, $42,$42, $3C,$3C
    ; Tile 4: message box frame
    DB $FF,$FF, $FF,$FF, $00,$00, $00,$00, $00,$00, $00,$00, $FF,$FF, $FF,$FF
GlyphsEnd:

INCLUDE "gfx.asm"
INCLUDE "text.asm"
