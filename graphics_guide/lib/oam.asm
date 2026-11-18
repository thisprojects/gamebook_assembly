; =============================================================
; oam.asm - hardware sprites (Chapter 6)
; =============================================================
; The Game Boy draws up to 40 sprites for you.  Each one is four bytes
; in OAM (object attribute memory): Y + 16, X + 8, tile, flags.
; Instead of writing OAM directly (only allowed in VBlank), the program
; builds a copy in work RAM - the "shadow OAM" - and once per frame a
; tiny routine in high RAM tells the DMA hardware to copy all 160 bytes.
;
;   oam_init        copy the DMA routine to HRAM and hide every sprite
;   oam_clear       hide every sprite
;   oam_begin       start a new frame's list of sprites
;   oam_add         B = x, C = y (screen pixels), D = tile, E = flags
;   draw_metasprite HL = definition, B = x, C = y: add a group of sprites
;   oam_end         hide the sprites this frame did not use
;   hOAMDMA         (in HRAM) call during VBlank to copy the shadow OAM
;
; A metasprite definition is a count, then for each part four bytes:
; y offset, x offset, tile, flags.

SECTION "ShadowOAM", WRAM0, ALIGN[8]
wShadowOAM: DS 160

SECTION "OAMVars", WRAM0
wOAMNext:    DS 1       ; offset of the next free entry in the shadow OAM
wMetaCount:  DS 1

SECTION "OAMDMACode", ROM0
OAMDMACode:
LOAD "OAMDMA", HRAM
hOAMDMA:
    LD A, HIGH(wShadowOAM)
    LDH [rDMA], A           ; Start the copy: wShadowOAM -> OAM
    LD A, 40
.wait:
    DEC A                   ; The CPU can only see HRAM while DMA runs,
    JR NZ, .wait            ; so this waiting loop has to live there
    RET
ENDL
OAMDMACodeEnd:

SECTION "OAMRoutines", ROM0

oam_init:
    LD HL, OAMDMACode
    LD DE, hOAMDMA
    LD BC, OAMDMACodeEnd - OAMDMACode
    CALL copy_bytes
oam_clear:
    LD HL, wShadowOAM
    LD BC, 160
    XOR A
    CALL fill_bytes         ; Y = 0 puts a sprite above the screen: invisible
    XOR A
    LD [wOAMNext], A
    RET

oam_begin:
    XOR A
    LD [wOAMNext], A
    RET

oam_add:
    LD A, [wOAMNext]
    CP 160
    RET NC                  ; All 40 sprites in use
    LD L, A
    LD H, HIGH(wShadowOAM)
    LD A, C
    ADD 16
    LD [HL+], A
    LD A, B
    ADD 8
    LD [HL+], A
    LD A, D
    LD [HL+], A
    LD A, E
    LD [HL+], A
    LD A, L
    LD [wOAMNext], A
    RET

draw_metasprite:
    LD A, [HL+]
    OR A
    RET Z                   ; a group with no parts draws nothing
    LD [wMetaCount], A
.next:
    PUSH BC
    LD A, [HL+]             ; y offset
    ADD C
    LD C, A
    LD A, [HL+]             ; x offset
    ADD B
    LD B, A
    LD A, [HL+]
    LD D, A                 ; tile
    LD A, [HL+]
    LD E, A                 ; flags
    PUSH HL
    CALL oam_add
    POP HL
    POP BC
    LD A, [wMetaCount]
    DEC A
    LD [wMetaCount], A
    JR NZ, .next
    RET

oam_end:
    LD A, [wOAMNext]
    LD L, A
    LD H, HIGH(wShadowOAM)
.hide:
    LD A, L
    CP 160
    RET NC
    XOR A
    LD [HL+], A
    JR .hide
