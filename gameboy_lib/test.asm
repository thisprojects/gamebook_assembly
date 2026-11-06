INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]
    NOP
    JP Start
    DS $150 - @, 0       ; Room for the cartridge header (rgbfix fills it in)

SECTION "Main", ROM0[$150]
Start:
    ; --- Main program ---
    CALL debug_init

    ; Test 1: Print a string
    LD HL, msg_hello
    CALL print_string
    LD A, 13
    RST $10             ; Newline

    ; Test 2: Do some maths and print the result
    LD A, 25
    ADD A, 17           ; 25 + 17 = 42
    CALL print_number   ; Should display 42
    LD A, 13
    RST $10             ; Newline

    ; Test 3: Conditional logic - print PASS or FAIL
    LD A, 42
    CP 42               ; Is A equal to 42?
    JP NZ, test_fail
    LD HL, msg_pass
    CALL print_string
    JP test_done
test_fail:
    LD HL, msg_fail
    CALL print_string
test_done:
    LD A, 13
    RST $10             ; Newline

Done:
    HALT                 ; Nothing left to do: sleep forever
    NOP
    JR Done

msg_hello:  DB "Debug output test", 0
msg_pass:   DB "Test PASSED", 0
msg_fail:   DB "Test FAILED", 0

    INCLUDE "debug_output.asm"
