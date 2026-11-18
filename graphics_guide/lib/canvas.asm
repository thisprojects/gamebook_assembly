; =============================================================
; canvas.asm - drawing pixels, lines and shapes (Chapters 3-5)
; =============================================================
; The canvas is a 128 x 128 pixel picture kept in work RAM.  It is
; laid out exactly like 256 tiles of video memory (16 tiles across,
; 16 down, 16 bytes each), so once it is drawn it can be copied
; straight into VRAM.  Colours are 0-3.
;
;   canvas_clear   A = colour: fill the whole canvas
;   plot           B = x, C = y, D = colour: set one pixel
;   toggle_pixel   B = x, C = y: invert one pixel (colour 0 <-> 3, 1 <-> 2)
;   draw_hline     B = x, C = y, E = length, D = colour
;   draw_vline     B = x, C = y, E = length, D = colour
;   draw_line      B = x0, C = y0, D = x1, E = y1, wColour = colour
;   draw_rect      B = x, C = y, D = width, E = height, wColour = colour
;   fill_rect      B = x, C = y, D = width, E = height, wColour = colour
;   draw_circle    B = cx, C = cy, E = radius, wColour = colour
;   fill_circle    B = cx, C = cy, E = radius, wColour = colour
;   canvas_to_vram copy the canvas into tiles 0-255 (LCD must be off)
;   canvas_map     arrange map tiles so the canvas appears on screen
; Pixels outside 0-127 (including "negative" ones, which are 128-255 as
; unsigned bytes) are quietly ignored, so shapes may hang over the edges.
; Zero-sized rectangles and lines draw nothing; a circle of radius 0 is one pixel.

DEF CANVAS_W EQU 128

SECTION "Canvas", WRAMX[$D000]
wCanvas: DS 4096

SECTION "CanvasVars", WRAM0
wColour:  DS 1          ; colour used by the line and shape routines
wLineX:   DS 1
wLineY:   DS 1
wDX:      DS 1
wDY:      DS 1
wSX:      DS 1
wSY:      DS 1
wMajor:   DS 1
wMinor:   DS 1
wAcc:     DS 1
wCount:   DS 1
wSteep:   DS 1
wRectX:   DS 1
wRectY:   DS 1
wRectW:   DS 1
wRectH:   DS 1
wCX:      DS 1
wCY:      DS 1
wCirX:    DS 1
wCirY:    DS 1
wCirErr:  DS 2          ; 16-bit signed error term

SECTION "CanvasRoutines", ROM0

; --- Fill the whole canvas with colour A ---
; A colour is two bits, one in each bit-plane, so every byte of plane 0
; is $00 or $FF and so is every byte of plane 1.
canvas_clear:
    LD D, 0                 ; D = plane 0 byte
    LD E, 0                 ; E = plane 1 byte
    BIT 0, A
    JR Z, .no0
    DEC D                   ; $00 -> $FF
.no0:
    BIT 1, A
    JR Z, .no1
    DEC E
.no1:
    LD HL, wCanvas
    LD BC, 2048             ; 2048 pairs of bytes = 4096 bytes
.loop:
    LD A, D
    LD [HL+], A
    LD A, E
    LD [HL+], A
    DEC BC
    LD A, B
    OR C
    JR NZ, .loop
    RET

; --- Work out where a pixel lives ---
; In: B = x, C = y.  Out: HL = address of the plane-0 byte, E = bit mask.
pixel_addr:
    LD A, C
    SRL A
    SRL A
    SRL A                   ; y / 8 = which row of tiles
    ADD HIGH(wCanvas)
    LD H, A                 ; high byte = $D0 + tile row (16 tiles x 16 bytes = $100 per row)
    LD A, C
    AND 7                   ; line within the tile
    ADD A                   ; x2: two bytes per line
    LD L, A
    LD A, B
    AND %01111000           ; (x / 8) * 8
    ADD A                   ; (x / 8) * 16 = offset of the tile within its row
    OR L
    LD L, A
    LD A, B
    AND 7                   ; pixel within the byte
    LD E, A
    LD A, $80
    JR Z, .got
.shift:
    SRL A
    DEC E
    JR NZ, .shift
.got:
    LD E, A                 ; E = mask for this pixel
    RET

; --- Set pixel (B, C) to colour D ---
plot:
    LD A, B
    OR C
    BIT 7, A
    RET NZ                  ; either coordinate is 128 or more: off the canvas, do nothing
    CALL pixel_addr
    BIT 0, D
    JR Z, .clear0
    LD A, [HL]
    OR E
    LD [HL+], A
    JR .plane1
.clear0:
    LD A, E
    CPL
    AND [HL]
    LD [HL+], A
.plane1:
    BIT 1, D
    JR Z, .clear1
    LD A, [HL]
    OR E
    LD [HL], A
    RET
.clear1:
    LD A, E
    CPL
    AND [HL]
    LD [HL], A
    RET

; --- Invert pixel (B, C): both bit-planes flip ---
toggle_pixel:
    LD A, B
    OR C
    BIT 7, A
    RET NZ
    CALL pixel_addr
    LD A, [HL]
    XOR E
    LD [HL+], A
    LD A, [HL]
    XOR E
    LD [HL], A
    RET

; --- Horizontal line: E pixels starting at (B, C) ---
draw_hline:
    LD A, E
    OR A
    RET Z
.loop:
    PUSH BC
    PUSH DE
    CALL plot
    POP DE
    POP BC
    INC B
    DEC E
    JR NZ, .loop
    RET

; --- Vertical line: E pixels starting at (B, C) ---
draw_vline:
    LD A, E
    OR A
    RET Z
.loop:
    PUSH BC
    PUSH DE
    CALL plot
    POP DE
    POP BC
    INC C
    DEC E
    JR NZ, .loop
    RET

; --- Bresenham line from (B, C) to (D, E) in colour wColour ---
; The long axis is stepped one pixel at a time.  The short axis
; accumulates its distance in wAcc and steps whenever that passes the
; long distance.  Everything fits in 8 bits for a 128 pixel canvas.
draw_line:
    LD A, B
    LD [wLineX], A
    LD A, C
    LD [wLineY], A
    LD A, D                 ; dx = |x1 - x0|, sx = direction
    SUB B
    LD B, 1
    JR NC, .dx_ok
    CPL
    INC A
    LD B, $FF
.dx_ok:
    LD [wDX], A
    LD A, B
    LD [wSX], A
    LD A, E                 ; dy = |y1 - y0|, sy = direction
    SUB C
    LD B, 1
    JR NC, .dy_ok
    CPL
    INC A
    LD B, $FF
.dy_ok:
    LD [wDY], A
    LD A, B
    LD [wSY], A
    LD A, [wDX]
    LD B, A
    LD A, [wDY]
    CP B                    ; which distance is longer?
    JR C, .shallow
    LD [wMajor], A          ; steep: y is the long axis
    LD A, B
    LD [wMinor], A
    LD A, 1
    LD [wSteep], A
    JR .start
.shallow:
    LD A, B
    LD [wMajor], A          ; shallow: x is the long axis
    LD A, [wDY]
    LD [wMinor], A
    XOR A
    LD [wSteep], A
.start:
    LD A, [wMajor]
    LD [wCount], A
    SRL A                   ; start the accumulator half-way for even rounding
    LD [wAcc], A
.loop:
    LD A, [wLineX]
    LD B, A
    LD A, [wLineY]
    LD C, A
    LD A, [wColour]
    LD D, A
    CALL plot
    LD A, [wCount]
    OR A
    RET Z                   ; drawn the last pixel
    DEC A
    LD [wCount], A
    LD A, [wMinor]
    LD B, A
    LD A, [wAcc]
    ADD B
    LD C, A                 ; C = accumulator + minor
    LD A, [wMajor]
    LD B, A
    LD A, C
    CP B
    JR C, .keep             ; accumulator still below the long distance: no short step
    SUB B
    LD [wAcc], A
    LD A, [wSteep]
    OR A
    JR Z, .minor_y
    CALL step_x             ; steep line: the short axis is x
    JR .major
.minor_y:
    CALL step_y
    JR .major
.keep:
    LD A, C
    LD [wAcc], A
.major:
    LD A, [wSteep]
    OR A
    JR Z, .major_x
    CALL step_y
    JR .loop
.major_x:
    CALL step_x
    JR .loop

step_x:
    LD A, [wSX]
    LD B, A
    LD A, [wLineX]
    ADD B
    LD [wLineX], A
    RET

step_y:
    LD A, [wSY]
    LD B, A
    LD A, [wLineY]
    ADD B
    LD [wLineY], A
    RET

; --- Rectangles: top-left (B, C), size D x E ---
draw_rect:
    LD A, D
    OR A
    RET Z                   ; no width
    LD A, E
    OR A
    RET Z                   ; no height
    LD A, B
    LD [wRectX], A
    LD A, C
    LD [wRectY], A
    LD A, D
    LD [wRectW], A
    LD A, E
    LD [wRectH], A
    LD A, [wColour]
    LD D, A
    LD A, [wRectW]
    LD E, A
    CALL draw_hline         ; top
    LD A, [wRectX]
    LD B, A
    LD A, [wRectY]
    LD C, A
    LD A, [wRectH]
    ADD C
    DEC A
    LD C, A
    LD A, [wRectW]
    LD E, A
    LD A, [wColour]
    LD D, A
    CALL draw_hline         ; bottom
    LD A, [wRectX]
    LD B, A
    LD A, [wRectY]
    LD C, A
    LD A, [wRectH]
    LD E, A
    LD A, [wColour]
    LD D, A
    CALL draw_vline         ; left
    LD A, [wRectX]
    LD B, A
    LD A, [wRectW]
    ADD B
    DEC A
    LD B, A
    LD A, [wRectY]
    LD C, A
    LD A, [wRectH]
    LD E, A
    LD A, [wColour]
    LD D, A
    JP draw_vline           ; right

fill_rect:
    LD A, E
    OR A
    RET Z                   ; no height: nothing to draw (the loop below counts down from E)
    LD A, D
    LD [wRectW], A
    LD A, E
    LD [wRectH], A
.row:
    LD A, [wRectW]
    LD E, A
    LD A, [wColour]
    LD D, A
    PUSH BC
    CALL draw_hline
    POP BC
    INC C
    LD A, [wRectH]
    DEC A
    LD [wRectH], A
    JR NZ, .row
    RET

; --- Circles (midpoint algorithm) ---
; x starts at the radius and y at 0.  Each step moves y up by one, and
; x down by one whenever the error term says the true circle has
; crossed to the inner pixel.  Eight symmetric pixels are plotted.
draw_circle:
    LD A, E
    OR A
    JR Z, circle_point
    CALL circle_setup
.loop:
    CALL plot8
    CALL circle_step
    JR NC, .loop            ; carry set when x < y: done
    RET

fill_circle:
    LD A, E
    OR A
    JR Z, circle_point
    CALL circle_setup
.loop:
    CALL span8
    CALL circle_step
    JR NC, .loop
    RET

circle_point:               ; radius 0 is a single pixel at the centre
    LD A, [wColour]
    LD D, A
    JP plot

circle_setup:
    LD A, B
    LD [wCX], A
    LD A, C
    LD [wCY], A
    LD A, E
    LD [wCirX], A
    XOR A
    LD [wCirY], A
    LD A, 1                 ; err = 1 - radius, as a 16-bit signed number
    SUB E
    LD [wCirErr], A
    SBC A                   ; $FF if that went below zero, else $00: the high byte
    LD [wCirErr + 1], A
    RET

; Advance one step.  Returns carry set when finished (x < y).
circle_step:
    LD A, [wCirY]
    INC A
    LD [wCirY], A
    LD A, [wCirErr]
    LD L, A
    LD A, [wCirErr + 1]
    LD H, A
    BIT 7, H
    JR Z, .inner
    LD A, [wCirY]           ; err < 0: err += 2y + 1
    LD E, A
    LD D, 0
    ADD HL, DE
    ADD HL, DE
    INC HL
    JR .store
.inner:
    LD A, [wCirX]           ; err >= 0: x--, err += 2(y - x) + 1
    DEC A
    LD [wCirX], A
    LD B, A
    LD A, [wCirY]
    SUB B                   ; y - x (may be negative: sign-extend)
    LD E, A
    LD D, 0
    JR NC, .pos
    DEC D
.pos:
    ADD HL, DE
    ADD HL, DE
    INC HL
.store:
    LD A, L
    LD [wCirErr], A
    LD A, H
    LD [wCirErr + 1], A
    LD A, [wCirY]
    LD B, A
    LD A, [wCirX]
    CP B                    ; carry if x < y
    RET

; Plot the eight mirror images of (x, y) around the centre.
plot8:
    LD A, [wCirX]
    LD E, A
    LD A, [wCirY]
    LD D, A
    CALL plot4
    LD A, [wCirY]
    LD E, A
    LD A, [wCirX]
    LD D, A
    ; fall through to plot4 for the swapped pair

; plot (cx +- E, cy +- D) in wColour
plot4:
    LD A, [wCX]
    ADD E
    LD B, A
    LD A, [wCY]
    ADD D
    LD C, A
    CALL plot_colour
    LD A, [wCX]
    SUB E
    LD B, A
    CALL plot_colour
    LD A, [wCY]
    SUB D
    LD C, A
    CALL plot_colour
    LD A, [wCX]
    ADD E
    LD B, A
    JP plot_colour

plot_colour:
    PUSH DE
    LD A, [wColour]
    LD D, A
    CALL plot
    POP DE
    RET

; Horizontal spans for the filled circle: widths 2x+1 at cy +- y and 2y+1 at cy +- x.
span8:
    LD A, [wCirX]
    LD E, A
    LD A, [wCirY]
    LD D, A
    CALL span2
    LD A, [wCirY]
    LD E, A
    LD A, [wCirX]
    LD D, A
span2:                      ; spans of half-width E at cy + D and cy - D
    LD A, [wCX]
    SUB E
    LD B, A                 ; B = left end
    LD A, E
    ADD A
    INC A
    LD E, A                 ; E = length 2E + 1
    LD A, [wCY]
    ADD D
    LD C, A
    PUSH BC
    PUSH DE
    LD A, [wColour]
    LD D, A
    CALL draw_hline
    POP DE
    POP BC
    LD A, [wCY]
    SUB D
    LD C, A
    LD A, [wColour]
    LD D, A
    JP draw_hline

; --- Copy the canvas into video memory (the LCD must be off) ---
canvas_to_vram:
    LD HL, wCanvas
    LD DE, VRAM_TILES
    LD BC, 4096
    JP copy_bytes

; --- Fill 16 x 16 tiles of map with tile numbers 0-255, so the canvas shows
;     up on screen at column 2, row 1 ---
canvas_map:
    LD HL, VRAM_MAP0 + 32 + 2
    XOR A
    LD C, 16                ; 16 rows...
.row:
    LD B, 16                ; ...of 16 tiles
.col:
    LD [HL+], A
    INC A
    DEC B
    JR NZ, .col
    LD DE, 32 - 16
    ADD HL, DE              ; to the start of the next map row
    DEC C
    JR NZ, .row
    RET

; --- end of canvas.asm
