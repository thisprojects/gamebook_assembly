; =============================================================
; tilemap.asm - a shadow copy of the tile map, and flood fill (Chapter 5)
; =============================================================
; Editing the real map is only allowed in VBlank, so the program draws
; into a copy in work RAM and copies it to VRAM when it is finished.
;
;   shadow_fill      A = tile: fill the whole shadow map
;   shadow_set       A = tile, B = column, C = row
;   shadow_hline     A = tile, B = column, C = row, E = length: a row of tiles
;   shadow_vline     A = tile, B = column, C = row, E = length: a column of tiles
;   shadow_addr      B = column, C = row -> HL (keeps BC)
;   shadow_to_vram   copy the shadow map to the real map (LCD must be off)
;   flood_fill       A = new tile, B = column, C = row: replace the connected
;                    region of identical tiles that contains (B, C)
;
; flood_fill keeps its list of squares still to visit on the CPU stack,
; so the stack grows by about 8 bytes per square filled.

SECTION "ShadowMap", WRAM0
wShadowMap: DS 32 * 32
wFillOld:   DS 1
wFillNew:   DS 1
wFillSP:    DS 2
wShadowTmp: DS 1

SECTION "TilemapRoutines", ROM0

shadow_fill:
    LD HL, wShadowMap
    LD BC, 32 * 32
    JP fill_bytes

shadow_addr:
    LD H, 0
    LD L, C
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL              ; row * 32
    LD DE, wShadowMap
    ADD HL, DE
    LD E, B
    LD D, 0
    ADD HL, DE
    RET

shadow_set:
    LD [wShadowTmp], A
    CALL shadow_addr
    LD A, [wShadowTmp]
    LD [HL], A
    RET

; --- A line made of tiles: no pixel work at all ---
shadow_hline:
    LD D, A
.loop:
    LD A, D
    PUSH BC
    PUSH DE                 ; shadow_set borrows DE: keep the tile (D) and the count (E)
    CALL shadow_set
    POP DE
    POP BC
    INC B
    DEC E
    JR NZ, .loop
    RET

shadow_vline:
    LD D, A
.loop:
    LD A, D
    PUSH BC
    PUSH DE                 ; shadow_set borrows DE: keep the tile (D) and the count (E)
    CALL shadow_set
    POP DE
    POP BC
    INC C
    DEC E
    JR NZ, .loop
    RET

shadow_to_vram:
    LD HL, wShadowMap
    LD DE, VRAM_MAP0
    LD BC, 32 * 32
    JP copy_bytes

flood_fill:
    LD [wFillNew], A
    CALL shadow_addr
    LD A, [HL]
    LD [wFillOld], A
    LD A, [wFillNew]
    LD E, A
    LD A, [wFillOld]
    CP E
    RET Z                   ; already the new tile: nothing to do (and no endless loop)
    LD [wFillSP], SP        ; remember where the stack was, to know when it is empty
    PUSH BC                 ; the first square to visit
.next:
    LD HL, SP + 0
    LD A, [wFillSP]
    CP L
    JR NZ, .visit
    LD A, [wFillSP + 1]
    CP H
    RET Z                   ; stack back where it began: finished
.visit:
    POP BC
    LD A, B
    CP 32
    JR NC, .next            ; off the left or right of the map (a "negative" column is >= 32)
    LD A, C
    CP 32
    JR NC, .next
    CALL shadow_addr
    LD A, [wFillOld]
    CP [HL]
    JR NZ, .next            ; a wall or an already-filled square
    LD A, [wFillNew]
    LD [HL], A
    INC B
    PUSH BC                 ; right
    DEC B
    DEC B
    PUSH BC                 ; left
    INC B
    INC C
    PUSH BC                 ; below
    DEC C
    DEC C
    PUSH BC                 ; above
    JR .next

; --- end of tilemap.asm
