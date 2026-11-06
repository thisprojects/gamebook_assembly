INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]
    NOP
    JP Start
    DS $150 - @, 0       ; Room for the cartridge header (rgbfix fills it in)

SECTION "Main", ROM0[$150]
Start:
    ; Set up the screen
    CALL debug_init

    ; Print prompt
    LD DE, prompt
    LD BC, prompt_len
    CALL print_block

    ; Wait for a button press.  Writing to the joypad register chooses
    ; which group of buttons to read; the 0 bits we read back are the
    ; buttons being held down.
wait_loop:
    LD A, %00010000      ; Bit 5 = 0: select the A, B, Select, Start buttons
    LDH [rP1], A
    LDH A, [rP1]         ; Read twice - the hardware needs a moment to settle
    LDH A, [rP1]
    BIT 0, A             ; Bit 0 = A button (0 means pressed)
    JR Z, a_pressed
    BIT 1, A             ; Bit 1 = B button
    JR Z, b_pressed
    JR wait_loop         ; Neither: keep waiting

a_pressed:
    LD A, 'A'
    JR show_key
b_pressed:
    LD A, 'B'
show_key:
    RST $10              ; print it

Done:
    HALT                 ; Nothing left to do: sleep forever
    NOP
    JR Done

prompt:
    DB "Press A or B: "
DEF prompt_len EQU @ - prompt

    INCLUDE "debug_output.asm"
