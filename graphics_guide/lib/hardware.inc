; =============================================================
; hardware.inc - Game Boy hardware register names
; =============================================================
; The Game Boy has no ROM routines and no IN/OUT instructions.
; Everything - screen, sound, buttons - is controlled by reading and
; writing memory addresses in the range $FF00-$FFFF.  These names
; just make the numbers readable.  Use them with LDH.

DEF rP1    EQU $FF00      ; Joypad
DEF rDIV   EQU $FF04      ; Divider (counts up all the time)
DEF rTIMA  EQU $FF05      ; Timer counter
DEF rTAC   EQU $FF07      ; Timer control
DEF rIF    EQU $FF0F      ; Interrupt flags (which interrupts are waiting)
DEF rLCDC  EQU $FF40      ; LCD control
DEF rSTAT  EQU $FF41      ; LCD status
DEF rSCY   EQU $FF42      ; Background scroll Y
DEF rSCX   EQU $FF43      ; Background scroll X
DEF rLY    EQU $FF44      ; Current scanline (0-153)
DEF rLYC   EQU $FF45      ; Scanline compare
DEF rDMA   EQU $FF46      ; OAM DMA start
DEF rBGP   EQU $FF47      ; Background palette (shades)
DEF rOBP0  EQU $FF48      ; Sprite palette 0
DEF rOBP1  EQU $FF49      ; Sprite palette 1
DEF rWY    EQU $FF4A      ; Window Y position
DEF rWX    EQU $FF4B      ; Window X position + 7
DEF rVBK   EQU $FF4F      ; (Game Boy Color) VRAM bank
DEF rHDMA1 EQU $FF51      ; (Game Boy Color) DMA source, high byte
DEF rHDMA2 EQU $FF52      ; (Game Boy Color) DMA source, low byte
DEF rHDMA3 EQU $FF53      ; (Game Boy Color) DMA destination, high byte
DEF rHDMA4 EQU $FF54      ; (Game Boy Color) DMA destination, low byte
DEF rHDMA5 EQU $FF55      ; (Game Boy Color) DMA length and start
DEF rBCPS  EQU $FF68      ; (Game Boy Color) background palette index
DEF rBCPD  EQU $FF69      ; (Game Boy Color) background palette data
DEF rOCPS  EQU $FF6A      ; (Game Boy Color) sprite palette index
DEF rOCPD  EQU $FF6B      ; (Game Boy Color) sprite palette data
DEF rIE    EQU $FFFF      ; Interrupt enable

; --- rLCDC bits ---
DEF LCDCF_ON      EQU %10000000   ; LCD on
DEF LCDCF_WIN9C00 EQU %01000000   ; Window map is at $9C00 (else $9800)
DEF LCDCF_WINON   EQU %00100000   ; Window on
DEF LCDCF_BG8000  EQU %00010000   ; Background/window tiles come from $8000 (else $8800 signed)
DEF LCDCF_BG9C00  EQU %00001000   ; Background map is at $9C00 (else $9800)
DEF LCDCF_OBJ16   EQU %00000100   ; Sprites are 8x16 (else 8x8)
DEF LCDCF_OBJON   EQU %00000010   ; Sprites on
DEF LCDCF_BGON    EQU %00000001   ; Background on

; --- rSTAT bits ---
DEF STATF_BUSY    EQU %00000010   ; Set in modes 2 and 3: VRAM/OAM may be unavailable
DEF STATF_LYC     EQU %01000000   ; Interrupt when LY == LYC

; --- rIE / rIF bits ---
DEF IEF_VBLANK    EQU %00000001
DEF IEF_STAT      EQU %00000010

; --- Sprite attribute bits ---
DEF OAMF_PRI      EQU %10000000   ; Sprite is drawn behind background colours 1-3
DEF OAMF_YFLIP    EQU %01000000
DEF OAMF_XFLIP    EQU %00100000
DEF OAMF_PAL1     EQU %00010000   ; Use rOBP1 instead of rOBP0

; --- Joypad bits (as returned by read_joypad: 1 = pressed) ---
DEF PADF_RIGHT    EQU %00000001
DEF PADF_LEFT     EQU %00000010
DEF PADF_UP       EQU %00000100
DEF PADF_DOWN     EQU %00001000
DEF PADF_A        EQU %00010000
DEF PADF_B        EQU %00100000
DEF PADF_SELECT   EQU %01000000
DEF PADF_START    EQU %10000000

; --- Memory areas ---
DEF VRAM_TILES    EQU $8000       ; 256 tiles of 16 bytes
DEF VRAM_MAP0     EQU $9800       ; first 32x32 tile map
DEF VRAM_MAP1     EQU $9C00       ; second 32x32 tile map
DEF OAM_RAM       EQU $FE00       ; 40 sprites of 4 bytes

; --- Screen size in tiles ---
DEF SCREEN_W      EQU 20
DEF SCREEN_H      EQU 18

; --- The standard LCDC setting used by the examples ---
DEF LCDC_NORMAL   EQU LCDCF_ON | LCDCF_BG8000 | LCDCF_OBJON | LCDCF_BGON
