INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]
    NOP
    JP Start
    DS $150 - @, 0       ; Room for the cartridge header (rgbfix fills it in)

SECTION "Main", ROM0[$150]
Start:
    ; Set up the screen
    CALL debug_init

    ; Point HL at our message
    LD HL, message

print_loop:
    LD A, [HL]          ; load next character
    CP 0                ; is it the null terminator?
    JP Z, Done          ; if yes, we're finished
    RST $10             ; print it
    INC HL              ; move to next character
    JP print_loop

Done:
    HALT                 ; Nothing left to do: sleep forever
    NOP
    JR Done

message:
    DB "Hello from Game Boy", 0

    INCLUDE "debug_output.asm"
