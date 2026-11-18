; boot.inc - the first lines of every program in this book.
; Puts the cartridge header space at $100 and starts your code at $150
; with the stack at the top of the first block of work RAM.

INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]
    NOP
    JP Start
    DS $150 - @, 0           ; rgbfix fills in the header here

SECTION "Main", ROM0[$150]
Start:
    LD SP, $CFFF             ; The stack grows down from the end of WRAM bank 0
