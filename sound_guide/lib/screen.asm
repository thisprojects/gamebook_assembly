; =============================================================
; screen.asm - a little text on the screen
; =============================================================
; Sound is not something you can see, so the examples print a few words
; saying what they are playing.  This is the screen set-up from the
; graphics book, folded into two routines (they use gfx.asm and text.asm).
;
;   screen_init   switch the LCD off, load the font, clear the screen, switch the LCD on
;   show_text     B = column, C = row, HL = zero-terminated string
;   print_note    A = note number: print its name at the cursor, like C-4 or F#5

SECTION "ScreenRoutines", ROM0

screen_init:
    CALL lcd_off
    LD A, %11100100
    CALL set_palette
    LD A, $20                   ; the space character is tile $20
    CALL fill_map
    CALL text_init
    XOR A
    LDH [rSCX], A
    LDH [rSCY], A
    JP lcd_on

show_text:
    PUSH HL                     ; print_at uses HL for its sums, so keep the string's address
    CALL print_at
    POP HL
    JP print_string

; --- Print a note's name: the letter and sharp sign from a table, then the octave ---
print_note:
    LD B, 0                     ; B counts octaves
.octave:
    CP 12
    JR C, .name
    SUB 12
    INC B
    JR .octave
.name:
    ADD A                       ; two characters per name
    LD E, A
    LD D, 0
    LD HL, NoteNames
    ADD HL, DE
    LD A, [HL+]
    PUSH HL
    CALL print_char
    POP HL
    LD A, [HL]
    CALL print_char
    LD A, B
    ADD '2'                     ; note 0 is C2, so octave 0 is "2"
    JP print_char

NoteNames:
    DB "C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"

; --- end of screen.asm
