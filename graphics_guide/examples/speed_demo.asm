; speed_demo.asm - Chapter 10: measuring the cost of copies and address maths
; Each routine is timed with the DIV register, which counts up once every
; 64 machine cycles.  The results are left in work RAM (wTime...).
SECTION "SpeedVars", WRAM0
wTimeCopy:     DS 1             ; plain copy loop, 1024 bytes
wTimeUnrolled: DS 1             ; unrolled copy
wTimeStack:    DS 1             ; copy with POP
wTimeFill:     DS 1             ; plain fill loop
wTimeFillPush: DS 1             ; fill with PUSH
wTimeAddr:     DS 1             ; 100 x map_addr
wTimeAddrFast: DS 1             ; 100 x map_addr_fast
wBuffer:       DS 1024

DEF BLOCKS EQU 64               ; 64 blocks of 16 bytes = 1024 bytes

; Start the stopwatch: writing any value to DIV resets it (A is left alone)
MACRO StartTimer
    LDH [rDIV], A
ENDM

; Stop the stopwatch and store the result (this does use A)
MACRO StopTimer
    LDH A, [rDIV]
    LD [\1], A
ENDM

INCLUDE "boot.inc"

    DI

    LD HL, TestData
    LD DE, wBuffer
    LD BC, 1024
    StartTimer
    CALL copy_bytes
    StopTimer wTimeCopy

    LD HL, TestData
    LD DE, wBuffer
    LD B, BLOCKS
    StartTimer
    CALL copy_unrolled
    StopTimer wTimeUnrolled

    LD HL, TestData
    LD DE, wBuffer
    LD B, BLOCKS
    StartTimer
    CALL copy_stack
    StopTimer wTimeStack

    LD HL, wBuffer
    LD BC, 1024
    LD A, $77
    StartTimer
    CALL fill_bytes
    StopTimer wTimeFill

    LD HL, wBuffer + 1024
    LD D, BLOCKS
    LD A, $33
    StartTimer
    CALL fill_stack
    StopTimer wTimeFillPush

    LD E, 100
    StartTimer
.addr:
    LD B, 17
    LD C, 9
    PUSH DE
    CALL map_addr
    POP DE
    DEC E
    JR NZ, .addr
    StopTimer wTimeAddr

    LD E, 100
    StartTimer
.addr_fast:
    LD B, 17
    LD C, 9
    CALL map_addr_fast
    DEC E
    JR NZ, .addr_fast
    StopTimer wTimeAddrFast

Done:
    HALT
    NOP
    JR Done

TestData:
    DS 1024, $5A

INCLUDE "gfx.asm"
INCLUDE "fast.asm"
