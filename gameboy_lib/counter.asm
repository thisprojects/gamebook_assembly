INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]
    NOP
    JP Start
    DS $150 - @, 0       ; Room for the cartridge header (rgbfix fills it in)

SECTION "Main", ROM0[$150]
Start:
    CALL debug_init

    ; Print header
    LD HL, msg_header
    CALL print_string
    LD A, 13
    RST $10              ; Newline

    ; Count from 0 to 20
    LD C, 0              ; C = counter
main_loop:
    LD A, C
    CALL print_number    ; Display current value
    LD A, ' '
    CALL print_char      ; Space separator

    INC C
    LD A, C
    CP 21                ; Reached 21 yet?
    JP NZ, main_loop     ; No - keep counting

    ; Finished counting
    LD A, 13
    RST $10              ; Newline
    LD A, 13
    RST $10              ; Newline

    ; Verify: C should be 21
    LD A, C
    CP 21
    JP NZ, verify_fail

    LD HL, msg_pass
    CALL print_string
    JP finished

verify_fail:
    LD HL, msg_fail
    CALL print_string
    LD A, C
    CALL print_number

finished:
    LD A, 13
    RST $10              ; Newline

Done:
    HALT                 ; Nothing left to do: sleep forever
    NOP
    JR Done

msg_header: DB "Counting 0 to 20:", 0
msg_pass:   DB "Verification PASSED", 0
msg_fail:   DB "FAILED! C = ", 0

    INCLUDE "debug_output.asm"
