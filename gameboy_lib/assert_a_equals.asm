; Assert: A should equal expected value
; If not, print an error message and the actual value
assert_a_equals:
    ; B = expected value, A = actual value
    CP B
    RET Z                ; Pass - values match
    ; Fail - display error
    PUSH AF
    LD HL, msg_assert
    CALL print_string
    POP AF
    CALL print_number    ; Show what A actually was
    LD A, 13
    RST $10              ; Newline
    RET

msg_assert: DB "ASSERT FAIL! A = ", 0
