INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]
    NOP
    JP Start
    DS $150 - @, 0       ; Room for the cartridge header (rgbfix fills it in)

SECTION "Main", ROM0[$150]
Start:
    ; Set up the screen
    CALL debug_init

    ; Print a string using the block print routine
    LD DE, message       ; DE = address of string
    LD BC, msg_len       ; BC = number of bytes to print
    CALL print_block     ; library routine: print BC bytes from DE

Done:
    HALT                 ; Nothing left to do: sleep forever
    NOP
    JR Done

message:
    DB "Printed with one CALL!"
DEF msg_len EQU @ - message

    INCLUDE "debug_output.asm"
