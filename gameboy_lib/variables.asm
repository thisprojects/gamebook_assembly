INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]
    NOP
    JP Start
    DS $150 - @, 0       ; Room for the cartridge header (rgbfix fills it in)

SECTION "Main", ROM0[$150]
Start:
    CALL debug_init          ; Set up the screen (do this first)

    ; --- my_byte (a single 8-bit value: 42) ---
    LD HL, label_byte
    CALL print_string        ; Print label
    LD A, [my_byte]          ; Load the byte from memory
    CALL print_number        ; Prints: 42
    LD A, 13
    RST $10                  ; Newline

    ; --- my_string (null-terminated: "Hello") ---
    LD HL, label_str
    CALL print_string        ; Print label
    LD HL, my_string
    CALL print_string        ; Prints: Hello
    LD A, 13
    RST $10                  ; Newline

    ; --- my_array (5 consecutive bytes: 1 2 3 4 5) ---
    ; PUSH HL before each print_number call to protect our pointer,
    ; POP HL after to restore it, then INC HL to advance to the next element.
    LD HL, label_arr
    CALL print_string        ; Print label
    LD HL, my_array          ; Point HL at the first element
    LD A, [HL]
    PUSH HL                  ; Save HL - print_number may clobber it
    CALL print_number        ; Prints: 1
    POP HL                   ; Restore HL so we know where we are
    LD A, 32
    RST $10                  ; Space
    INC HL                   ; Advance to element 2
    LD A, [HL]
    PUSH HL                  ; Save HL - print_number may clobber it
    CALL print_number        ; Prints: 2
    POP HL                   ; Restore HL so we know where we are
    LD A, 32
    RST $10                  ; Space
    INC HL                   ; Advance to element 3
    LD A, [HL]
    PUSH HL                  ; Save HL - print_number may clobber it
    CALL print_number        ; Prints: 3
    POP HL                   ; Restore HL so we know where we are
    LD A, 32
    RST $10                  ; Space
    INC HL                   ; Advance to element 4
    LD A, [HL]
    PUSH HL                  ; Save HL - print_number may clobber it
    CALL print_number        ; Prints: 4
    POP HL                   ; Restore HL so we know where we are
    LD A, 32
    RST $10                  ; Space
    INC HL                   ; Advance to element 5
    LD A, [HL]
    CALL print_number        ; Prints: 5 (no PUSH/POP needed - we're done with HL)
    LD A, 13
    RST $10                  ; Newline

Done:
    HALT                 ; Nothing left to do: sleep forever
    NOP
    JR Done

; --- Data ---
my_byte:   DB 42
my_string: DB "Hello", 0
my_array:  DB 1, 2, 3, 4, 5

; --- Output labels ---
label_byte: DB "my_byte:   ", 0
label_str:  DB "my_string: ", 0
label_arr:  DB "my_array:  ", 0

    INCLUDE "debug_output.asm"
