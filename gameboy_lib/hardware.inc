; =============================================================
; hardware.inc - Game Boy hardware register names
; =============================================================
; The Game Boy has no ROM routines and no IN/OUT instructions.
; Everything - screen, sound, buttons - is controlled by writing
; to memory addresses in the range $FF00-$FFFF.  These names just
; make the numbers readable.  Use them with LDH (see Chapter 8).

DEF rP1    EQU $FF00      ; Joypad
DEF rIF    EQU $FF0F      ; Interrupt flags (which interrupts are waiting)
DEF rNR10  EQU $FF10      ; Sound channel 1: sweep
DEF rNR11  EQU $FF11      ; Sound channel 1: duty and length
DEF rNR12  EQU $FF12      ; Sound channel 1: volume envelope
DEF rNR13  EQU $FF13      ; Sound channel 1: pitch, low 8 bits
DEF rNR14  EQU $FF14      ; Sound channel 1: trigger and pitch, high 3 bits
DEF rNR50  EQU $FF24      ; Sound master volume
DEF rNR51  EQU $FF25      ; Sound panning
DEF rNR52  EQU $FF26      ; Sound on/off
DEF rLCDC  EQU $FF40      ; LCD control
DEF rSTAT  EQU $FF41      ; LCD status
DEF rSCY   EQU $FF42      ; Background scroll Y
DEF rSCX   EQU $FF43      ; Background scroll X
DEF rLY    EQU $FF44      ; Current scanline (0-153)
DEF rBGP   EQU $FF47      ; Background palette
DEF rOBP0  EQU $FF48      ; Sprite palette 0
DEF rIE    EQU $FFFF      ; Interrupt enable

; --- rLCDC bits ---
DEF LCDCF_ON      EQU %10000000   ; LCD on
DEF LCDCF_BG8000  EQU %00010000   ; Background tiles come from $8000
DEF LCDCF_OBJON   EQU %00000010   ; Sprites on
DEF LCDCF_BGON    EQU %00000001   ; Background on

; --- rSTAT bits ---
DEF STATF_BUSY    EQU %00000010   ; Set in modes 2 and 3: VRAM may be unavailable

; --- rIE / rIF bits ---
DEF IEF_VBLANK    EQU %00000001

; --- Screen size in character cells ---
DEF SCREEN_W      EQU 20
DEF SCREEN_H      EQU 18

; --- Memory areas ---
DEF VRAM_TILES    EQU $8000
DEF VRAM_MAP      EQU $9800
DEF OAM_RAM           EQU $FE00
