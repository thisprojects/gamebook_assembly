; scroll_demo.asm - Chapter 7: scrolling a world, with a window HUD
; The camera moves one pixel right every frame.  Every 8 pixels a new
; column of the world is written into the map just outside the screen.
; A strip along the bottom is the window layer, which never scrolls.
SECTION "ScrollVars", WRAM0
wCamX: DS 2                     ; camera position in pixels, 0-1023 (the world is 1024 pixels wide)

INCLUDE "boot.inc"

    CALL lcd_off
    LD A, %11100100
    CALL set_palette

    LD HL, ScrollTiles
    LD DE, VRAM_TILES
    LD BC, ScrollTilesEnd - ScrollTiles
    CALL copy_bytes

    ; Fill the first 32 map columns with world columns 0-31
    LD B, 0
.fill:
    LD A, B
    PUSH BC
    CALL stream_column
    POP BC
    INC B
    LD A, B
    CP 32
    JR NZ, .fill

    ; The window shows its own map at $9C00: a row of boxes as a stand-in HUD
    LD HL, VRAM_MAP1
    LD B, SCREEN_W
    LD A, 3
.hud:
    LD [HL+], A
    DEC B
    JR NZ, .hud

    LD A, 7                     ; WX is the window's left edge + 7: this puts it at screen column 0
    LDH [rWX], A
    LD A, 136                   ; WY = 136: the window covers the bottom tile row (lines 136-143)
    LDH [rWY], A

    XOR A
    LD [wCamX], A
    LD [wCamX + 1], A
    LDH [rSCX], A
    LDH [rSCY], A

    LD A, LCDC_NORMAL | LCDCF_WINON | LCDCF_WIN9C00
    LDH [rLCDC], A

MainLoop:
    CALL wait_vblank            ; all VRAM writes happen right after this

    ; --- Move the camera one pixel (a 10-bit counter that wraps at 1024) ---
    LD A, [wCamX]
    INC A
    LD [wCamX], A
    JR NZ, .no_carry
    LD A, [wCamX + 1]
    INC A
    AND 3
    LD [wCamX + 1], A
.no_carry:
    LD A, [wCamX]
    LDH [rSCX], A               ; the hardware does the actual scrolling

    ; --- On every 8th pixel, stream in the column about to appear on the right ---
    AND 7
    JR NZ, MainLoop
    LD A, [wCamX]               ; world column = camX / 8 + 20, wrapped to 0-127
    SRL A
    SRL A
    SRL A
    LD B, A
    LD A, [wCamX + 1]
    ADD A
    ADD A
    ADD A
    ADD A
    ADD A                       ; high byte x 32
    ADD B
    ADD 20
    AND 127
    CALL stream_column
    JR MainLoop

ScrollTiles:
    ; Tile 0: sky (blank)
    DB $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
    ; Tile 1: ground (dotted, colour 2 and 3)
    DB $FF,$FF, $FF,$FF, $EE,$FF, $FF,$FF, $77,$FF, $FF,$FF, $EE,$FF, $FF,$FF
    ; Tile 2: grass on top
    DB $FF,$FF, $AA,$FF, $00,$FF, $00,$AA, $00,$55, $00,$AA, $00,$55, $00,$AA
    ; Tile 3: HUD box
    DB $FF,$FF, $81,$81, $81,$81, $81,$81, $81,$81, $81,$81, $81,$81, $FF,$FF
ScrollTilesEnd:

INCLUDE "gfx.asm"
INCLUDE "scroll.asm"
