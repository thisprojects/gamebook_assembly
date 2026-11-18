; =============================================================
; scroll.asm - hardware scrolling (Chapter 7)
; =============================================================
; The background map is 32 x 32 tiles (256 x 256 pixels), but the
; screen shows a 20 x 18 window onto it.  rSCX and rSCY say where the
; window sits, and the map wraps round at the edges, so the program
; only ever has to write the one new column (or row) of tiles that is
; about to scroll into view.
;
;   stream_column        A = world column (0-127): draw it into the map
;   stream_world_column  A = column, B = first row of a 64 x 64 world: write 19 tiles
;   stream_world_row     A = row, B = first column of that world: write 21 tiles
;
; The world is 128 columns wide.  WorldHeights holds the height of
; the ground in each column; stream_column turns that into sky, a
; grass-topped surface and solid ground below it.

DEF WORLD_COLUMNS EQU 128

SECTION "ScrollRoutines", ROM0

; Tiles: 0 = sky, 1 = ground, 2 = grass
stream_column:
    LD C, A
    LD E, A
    LD D, 0
    LD HL, WorldHeights
    ADD HL, DE
    LD B, [HL]              ; B = row where the surface is in this column
    LD A, C
    AND 31                  ; the map is only 32 columns wide, so wrap
    LD E, A
    LD D, 0
    LD HL, VRAM_MAP0
    ADD HL, DE              ; HL = top of that map column
    LD DE, 32               ; one row down = 32 bytes on
    LD C, 0                 ; C = row
.row:
    LD A, C
    CP B
    JR C, .sky
    JR Z, .top
    LD A, 1                 ; below the surface: ground
    JR .put
.top:
    LD A, 2                 ; the surface itself: grass
    JR .put
.sky:
    XOR A
.put:
    LD [HL], A
    ADD HL, DE
    INC C
    LD A, C
    CP SCREEN_H
    JR NZ, .row
    RET

WorldHeights:
FOR i, WORLD_COLUMNS
    DB 11 + ((i * 3 + i / 5) % 4)
ENDR


; --- Scrolling in both directions: a 64 x 64 tile world stored in ROM ---
; The map ring is 32 tiles in each direction, so a column of the world goes to map
; column (world column mod 32) and a row to map row (world row mod 32).  Both
; routines step through memory with pointers and never multiply per tile, so a whole
; column or row fits easily into one VBlank.

DEF WORLD_W EQU 64

; Writes world tiles (col, row) .. (col, row + 18) down map column (col mod 32).
stream_world_column:
    LD C, A                 ; C = world column
    LD H, 0
    LD L, B
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL              ; first row * 64
    LD E, C
    LD D, 0
    ADD HL, DE
    LD DE, WorldData
    ADD HL, DE              ; HL = source: WorldData + row * 64 + column
    PUSH HL
    LD A, B
    AND 31                  ; map row
    LD L, A
    LD H, 0
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL              ; * 32
    LD A, C
    AND 31                  ; map column
    LD E, A
    LD D, 0
    ADD HL, DE
    LD DE, VRAM_MAP0
    ADD HL, DE
    LD D, H
    LD E, L                 ; DE = destination in the map
    POP HL
    LD B, 19
.next:
    LD A, [HL]
    LD [DE], A
    LD A, L                 ; next world row: 64 bytes on
    ADD WORLD_W
    LD L, A
    JR NC, .src_ok
    INC H
.src_ok:
    LD A, E                 ; next map row: 32 bytes on, wrapping from the bottom to the top
    ADD 32
    LD E, A
    JR NC, .dst_ok
    INC D
.dst_ok:
    LD A, D
    CP HIGH(VRAM_MAP0) + 4
    JR NZ, .go
    LD D, HIGH(VRAM_MAP0)
.go:
    DEC B
    JR NZ, .next
    RET

; Writes world tiles (col, row) .. (col + 20, row) along map row (row mod 32),
; wrapping round the end of the map row.
stream_world_row:
    LD C, A                 ; C = world row
    LD H, 0
    LD L, A
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL              ; row * 64
    LD E, B
    LD D, 0
    ADD HL, DE
    LD DE, WorldData
    ADD HL, DE              ; HL = source
    PUSH HL
    LD A, C
    AND 31
    LD L, A
    LD H, 0
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    LD DE, VRAM_MAP0
    ADD HL, DE              ; HL = start of the map row
    LD A, B
    AND 31
    LD C, A                 ; C = map column we start at
    LD E, A
    LD D, 0
    ADD HL, DE
    LD D, H
    LD E, L                 ; DE = destination
    POP HL
    LD B, 21
.next:
    LD A, [HL+]
    LD [DE], A
    INC DE
    INC C
    LD A, C
    CP 32
    JR NZ, .go
    LD C, 0                 ; ran off the end of the map row: back to its start
    LD A, E
    SUB 32
    LD E, A
    JR NC, .go
    DEC D
.go:
    DEC B
    JR NZ, .next
    RET

; The world: tile 1 where (column XOR row) has bit 2 set (diagonal paths), tile 2
; (a flower) on a sparse grid of the rest, tile 0 (grass) everywhere else.
WorldData:
FOR wy, WORLD_W
FOR wx, WORLD_W
IF (((wx ^ wy) >> 2) & 1) != 0
    DB 1
ELIF ((wx % 4) == 1) && ((wy % 4) == 1)
    DB 2
ELSE
    DB 0
ENDC
ENDR
ENDR

; --- end of scroll.asm
