; =============================================================
; joypad.asm - reading the buttons (Chapter 11)
; =============================================================
;   read_joypad   reads the pad; afterwards
;                   wJoy    = every button held now   (1 = pressed)
;                   wJoyNew = buttons that went down since the last call
;                 and A = wJoy.  Bits are the PADF_ values in hardware.inc.
; Call it once per frame, just after the frame begins.

SECTION "JoypadVars", WRAM0
wJoy:    DS 1
wJoyNew: DS 1

SECTION "JoypadRoutines", ROM0

; The eight buttons share four input lines.  Writing to rP1 chooses which
; group is connected: bit 4 low selects the direction pad, bit 5 low the
; four buttons.  A pressed button reads as 0, so the result is inverted.
read_joypad:
    LD A, %00100000         ; bit 5 high, bit 4 low: select the direction pad
    LDH [rP1], A
    LDH A, [rP1]
    LDH A, [rP1]            ; read a few times: the lines take a moment to settle
    LDH A, [rP1]
    CPL                     ; pressed = 1
    AND $0F
    LD B, A                 ; low nibble: Down Up Left Right
    LD A, %00010000         ; select the buttons
    LDH [rP1], A
    LDH A, [rP1]
    LDH A, [rP1]
    LDH A, [rP1]
    CPL
    AND $0F
    SWAP A                  ; high nibble: Start Select B A
    OR B
    LD B, A                 ; B = all eight buttons
    LD A, %00110000
    LDH [rP1], A            ; deselect both groups
    LD A, [wJoy]
    CPL
    AND B                   ; held now and not held before = newly pressed
    LD [wJoyNew], A
    LD A, B
    LD [wJoy], A
    RET

; --- end of joypad.asm
