"""Tests for lib/*.asm and examples/*.asm: assemble every program with RGBDS, run it headless on an
emulated Game Boy (PyBoy) and check what ends up in video memory, work RAM and on the screen.
See tests/README.md.   Run:  .venv/bin/python tests/test_lib.py [test names]"""
import os, re, sys, traceback
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from harness import *
import build_book

BOOT = 150          # frames to let the emulated boot ROM and our start-up code finish
TESTS = []


def test(f):
    TESTS.append(f)
    return f


# ---------------------------------------------------------------- helpers
def font_rows():
    """Glyph rows from lib/font.inc: {ascii: [8 bytes]}"""
    rows = re.findall(r'db\s+((?:\$[0-9A-F]{2},?\s*){8})', open(f'{LIB}/font.inc').read(), re.I)
    return {32 + i: [int(x[1:], 16) for x in r.replace(',', ' ').split()] for i, r in enumerate(rows)}


def canvas_pixels(m):
    """128 x 128 canvas decoded from work RAM."""
    raw = m.read(0xD000, 4096)
    px = [[0] * 128 for _ in range(128)]
    for ty in range(16):
        for tx in range(16):
            t = tile_rows(raw[(ty * 16 + tx) * 16:(ty * 16 + tx) * 16 + 16])
            for r in range(8):
                for c in range(8):
                    px[ty * 8 + r][tx * 8 + c] = t[r][c]
    return px


def model_line(px, x0, y0, x1, y1, colour):
    """Python version of draw_line: step the long axis, accumulate the short one."""
    dx, dy = abs(x1 - x0), abs(y1 - y0)
    sx = 1 if x1 >= x0 else -1
    sy = 1 if y1 >= y0 else -1
    steep = dy >= dx
    major, minor = (dy, dx) if steep else (dx, dy)
    acc, x, y = major // 2, x0, y0
    for _ in range(major + 1):
        px[y][x] = colour
        acc += minor
        if acc >= major:
            acc -= major
            if steep:
                x += sx
            else:
                y += sy
        if steep:
            y += sy
        else:
            x += sx


def put(px, x, y, colour):
    if 0 <= x < 128 and 0 <= y < 128:       # pixels off the canvas are ignored
        px[y][x] = colour


def model_hline(px, x, y, n, colour):
    for i in range(n):
        put(px, x + i, y, colour)


def model_circle(px, cx, cy, r, colour, fill=False):
    if r == 0:
        put(px, cx, cy, colour)
        return
    x, y, err = r, 0, 1 - r
    while x >= y:
        if fill:
            for dy, half in ((y, x), (x, y)):
                for sy in (cy + dy, cy - dy):
                    model_hline(px, cx - half, sy, 2 * half + 1, colour)
        else:
            for a, b in ((x, y), (y, x)):
                for sx in (cx + a, cx - a):
                    for sy in (cy + b, cy - b):
                        put(px, sx, sy, colour)
        y += 1
        if err < 0:
            err += 2 * y + 1
        else:
            x -= 1
            err += 2 * (y - x) + 1


# ---------------------------------------------------------------- assembling
@test
def all_examples_assemble():
    names = sorted(f[:-4] for f in os.listdir(EXAMPLES) if f.endswith('.asm'))
    assert len(names) >= 17, names
    for n in names:
        build(n, cgb=(n in ('cgb_demo', 'hdma_demo')))


# ---------------------------------------------------------------- chapter 1
@test
def tiles_demo():
    m = Machine('tiles_demo', BOOT)
    mp = lambda c, r: m[0x9800 + r * 32 + c]
    assert all(mp(c, 0) == 3 and mp(c, 17) == 3 for c in range(20)), 'top/bottom frame'
    assert all(mp(0, r) == 3 and mp(19, r) == 3 for r in range(18)), 'side frame'
    assert mp(5, 5) == 1 and [mp(c, 9) for c in (9, 10, 11)] == [4, 4, 4]
    assert mp(1, 1) == 0 and mp(30, 30) == 0
    stripes = tile_rows(m.read(0x8000 + 4 * 16, 16))
    assert [r[0] for r in stripes] == [0, 0, 1, 1, 2, 2, 3, 3], stripes     # colour = plane0 | plane1 << 1
    sh = m.shades()
    assert sh[0][0] == 3, 'frame corner is black'
    assert sh[5 * 8 + 3][5 * 8 + 3] == 3, 'solid block'
    assert sh[9 * 8 + 3][9 * 8 + 3] == 1 and sh[9 * 8 + 5][9 * 8 + 3] == 2 and sh[9 * 8 + 7][9 * 8 + 3] == 3
    m.stop()


# ---------------------------------------------------------------- chapter 2
@test
def palette_demo():
    m = Machine('palette_demo', BOOT)
    table = [0b11100100, 0b10010000, 0b01000000, 0b00000000, 0b01000000, 0b10010000]
    step = m[m.sym['wStep']]
    assert m[0xFF47] == table[step]
    seen = {step}
    for _ in range(8):
        m.run(61)
        step = m[m.sym['wStep']]
        assert m[0xFF47] == table[step], (step, m[0xFF47])
        seen.add(step)
    assert seen == set(range(6)), seen
    # the bands: with the normal palette the four bands are four different shades
    m2 = Machine('palette_demo', BOOT)
    while m2[m2.sym['wStep']] != 0 or m2[0xFF47] != 0b11100100:
        m2.run(1)
    m2.run(3)                                   # the screen image lags the register by a frame
    sh = m2.shades()
    assert [sh[10][x] for x in (20, 60, 100, 140)] == [0, 1, 2, 3], [sh[10][x] for x in (20, 60, 100, 140)]
    m.stop(); m2.stop()


@test
def cgb_demo():
    m = Machine('cgb_demo', BOOT + 50, cgb=True)
    sc = m.screen()
    top = [sc[4][x] for x in (4, 44, 84, 124)]
    bottom = [sc[100][x] for x in (4, 44, 84, 124)]
    close = lambda a, b: all(abs(p - q) < 16 for p, q in zip(a, b))
    assert [close(c, e) for c, e in zip(top, [(248, 248, 248), (248, 0, 0), (0, 248, 0), (0, 0, 248)])] == [True] * 4, top
    assert [close(c, e) for c, e in zip(bottom, [(0, 0, 0), (248, 248, 0), (0, 248, 248), (248, 0, 248)])] == [True] * 4, bottom
    m.stop()


# ---------------------------------------------------------------- chapters 3-5
@test
def pixel_demo():
    m = Machine('pixel_demo', BOOT)
    px = canvas_pixels(m)
    for i in range(64):
        assert px[i][i] == i % 4, (i, px[i][i])
    assert px[20][100] == 0 and px[20][101] == 3, 'toggle: 100 plotted then removed, 101 inverted'
    assert sum(1 for r in px for v in r if v) == 48 + 1, 'only the diagonal (non-zero colours) and one toggled pixel'
    # the canvas was copied into VRAM tile for tile, and is on screen
    assert m.read(0x8000, 4096) == m.read(0xD000, 4096)
    sh = m.shades()
    ox, oy = 16, 8
    for i in range(1, 64):
        assert sh[oy + i][ox + i] == (i % 4), (i, sh[oy + i][ox + i])
    m.stop()


@test
def line_demo():
    m = Machine('line_demo', BOOT)
    got = canvas_pixels(m)
    want = [[0] * 128 for _ in range(128)]
    model_hline(want, 0, 0, 128, 3); model_hline(want, 0, 127, 128, 3)
    for y in range(128):
        want[y][0] = want[y][127] = 3
    model_line(want, 0, 0, 127, 127, 3)
    model_line(want, 127, 0, 0, 127, 2)
    model_line(want, 10, 100, 120, 30, 1)
    model_line(want, 64, 5, 70, 120, 1)
    bad = [(x, y) for y in range(128) for x in range(128) if got[y][x] != want[y][x]]
    assert not bad, f'{len(bad)} pixels differ, e.g. {bad[:5]}'
    # a line always touches both end points
    assert got[100][10] == 1 and got[30][120] == 1 and got[5][64] == 1 and got[120][70] == 1
    m.stop()


@test
def shapes_demo():
    m = Machine('shapes_demo', BOOT)
    got = canvas_pixels(m)
    want = [[0] * 128 for _ in range(128)]
    # hollow rectangle 50 x 30 at (4, 4)
    model_hline(want, 4, 4, 50, 3); model_hline(want, 4, 33, 50, 3)
    for y in range(4, 34):
        want[y][4] = want[y][53] = 3
    for r in range(30):
        model_hline(want, 70, 4 + r, 40, 2)
    model_circle(want, 32, 80, 24, 3)
    model_circle(want, 90, 85, 20, 1, fill=True)
    bad = [(x, y) for y in range(128) for x in range(128) if got[y][x] != want[y][x]]
    assert not bad, f'{len(bad)} pixels differ, e.g. {bad[:5]}'
    m.stop()


@test
def flood_demo():
    m = Machine('flood_demo', BOOT)
    mp = lambda c, r: m[0x9800 + r * 32 + c]
    for r in range(3, 12):
        for c in range(4, 16):
            wall = r in (3, 11) or c in (4, 15, 9)
            if wall:
                assert mp(c, r) == 2, ('wall', c, r)
            elif c < 9:
                assert mp(c, r) == 1, ('left room should be painted', c, r)
            else:
                assert mp(c, r) == 0, ('right room should be untouched', c, r)
    assert mp(0, 0) == 0 and mp(19, 17) == 0
    m.stop()


# ---------------------------------------------------------------- chapter 6
@test
def invader():
    m = Machine('invader', BOOT)
    s = m.sym
    frame, x0, ufo = m[s['wFrame']], m[s['wInvX']], m[s['wUfoX']]
    shadow = m.read(s['wShadowOAM'], 160)
    # three invaders (two sprites each), a fourth behind the bunkers, and a UFO: 10 sprites, the rest hidden
    assert all(shadow[i] == 0 for i in range(40, 160)), 'unused sprites must be hidden (Y = 0)'
    inv_tile = 3 if ((frame >> 4) & 1) == 0 else 4
    for k, y in enumerate((40, 56, 72)):
        left, right = shadow[8 * k:8 * k + 4], shadow[8 * k + 4:8 * k + 8]
        assert left == [y + 16, x0 + 8, inv_tile, 0], (k, left)
        assert right == [y + 16, x0 + 16, inv_tile, 0x20], (k, right)   # the same tile, flipped
    assert shadow[24:32] == [120 + 16, x0 + 8, 3, 0x80, 120 + 16, x0 + 16, 3, 0xA0], 'priority invader'
    assert shadow[32:36] == [36, (ufo - 16 + 8) & 255, 5, 0x10], 'UFO uses palette 1'
    # real OAM equals what the shadow held a frame ago: DMA is working
    oam = m.read(0xFE00, 160)
    assert oam[0] == 40 + 16 and oam[32] == 20 + 16, oam[:36]
    # visible on screen: an invader pixel appears where the first one is
    sh = m.shades()
    assert any(sh[40 + r][x0 + c] == 3 for r in range(8) for c in range(16)), 'invader drawn'
    # transparency: pixels of the sprite that are colour 0 show the checkerboard behind
    assert any(sh[40 + r][x0 + c] == 1 for r in range(8) for c in range(16)), 'checkerboard shows through'
    # hardware clipping: with the UFO parked off the left edge nothing wraps round onto the screen
    m.pb.memory[s['wUfoX']] = 4          # OAM x = -4: half of it is off the left edge
    m.run(3)
    sh = m.shades()
    assert not [c for r in range(20, 28) for c in range(152, 160) if sh[r][c] == 3], 'clipped sprite must not wrap'
    # priority: the invader on the bunker row is hidden by the bunkers (background colour 2) but shows in the gaps
    def dark(x_lo, x_hi):
        return sum(1 for r in range(120, 128) for c in range(x_lo, x_hi) if sh[r][c] == 3)
    m.pb.memory[s['wInvX']] = 25         # over the first bunker (columns 3-5 = pixels 24-47)
    m.run(4)                             # (the sprite table reaches the screen a frame or two later)
    sh = m.shades()
    assert dark(26, 40) == 0, 'the sprite must be behind the bunker'
    m.pb.memory[s['wInvX']] = 50         # in the gap between bunkers (pixels 48-71)
    m.run(4)
    sh = m.shades()
    assert dark(50, 66) > 0, 'the sprite shows in front of the empty background'
    # sprite palette 1 is the reverse of palette 0: the UFO's art shows lighter, not darker
    m.pb.memory[s['wUfoX']] = 90
    m.run(4)
    sh = m.shades()
    # the UFO's solid row (art row 5) is colour 3, which palette 1 maps to the lightest shade: a clean run of
    # 16 light pixels with no checkerboard showing, where palette 0 would have made it black
    row = ''.join(str(sh[25][c]) for c in range(60, 120))
    assert '0' * 14 in row, row
    m.stop()


@test
def sprites_beyond_ten_per_line_and_rotation():
    m = Machine('flicker_demo', BOOT)
    s = m.sym

    def drawn_blocks():
        row = m.shades()[84]
        xs = [x for x in range(160) if row[x] == 3]
        starts = [x for i, x in enumerate(xs) if i == 0 or xs[i - 1] != x - 1]
        return starts
    m.pb.memory[s['wRotate']] = 0
    m.run(3)
    fixed = drawn_blocks()
    assert len(fixed) == 10, f'the hardware draws only ten sprites per line, saw {len(fixed)}'
    seen = set()
    m.pb.memory[s['wRotate']] = 1
    for _ in range(40):
        m.run(1)
        blocks = drawn_blocks()
        assert len(blocks) == 10, len(blocks)
        seen |= set(blocks)
    assert len(seen) == 14, f'with rotation every sprite should be drawn at some time, saw {len(seen)}'
    m.stop()


@test
def hdma_demo():
    m = Machine('hdma_demo', BOOT, cgb=True)
    want = []
    for n in range(64):
        want += [(n * 4) & 255, (n * 3 + 1) & 255] * 8
    assert m.read(0x8000, 1024) == want, 'hardware copy'
    assert m.read(0x8000 + 1024, 1024) == want, 'CPU copy'
    sc = m.screen()
    assert any(sc[y][x] != sc[0][0] for y in range(0, 32) for x in range(0, 128)), 'tiles are on screen'
    m.stop()


# ---------------------------------------------------------------- chapter 7
def world_height(i):
    return 11 + ((i * 3 + i // 5) % 4)


@test
def scroll_demo():
    m = Machine('scroll_demo', BOOT)
    cam = m.word(m.sym['wCamX'])
    assert cam > 0
    assert m[0xFF4A] == 136 and m[0xFF4B] == 7 and m[0xFF40] & 0b01100000 == 0b01100000, 'window set up'
    # the scroll register tracks the camera (allow for one frame of lag)
    assert (m[0xFF43] - cam) % 256 in (0, 255, 1), (m[0xFF43], cam)
    cam = m.word(m.sym['wCamX'])
    first = cam // 8
    for col in range(first, first + 20):          # every column on screen is the right world column
        h = world_height(col % 128)
        for row in range(18):
            want = 0 if row < h else (2 if row == h else 1)
            assert m[0x9800 + row * 32 + (col % 32)] == want, (col, row)
    # window map holds the HUD boxes
    assert m.read(0x9C00, 20) == [3] * 20
    m.run(300)
    cam2 = m.word(m.sym['wCamX'])
    assert (cam2 - cam) % 1024 in range(290, 310), (cam, cam2)
    first = cam2 // 8
    for col in range(first, first + 20):
        assert m[0x9800 + 5 * 32 + (col % 32)] == (0 if 5 < world_height(col % 128) else 1), col
    m.stop()


@test
def parallax_demo():
    m = Machine('parallax_demo', BOOT)
    bars = lambda col: (col * 3 + col // 4) & 7        # bar position in the tile of map column col

    def row_pixels(sh, y):
        return [1 if sh[y][x] == 3 else 0 for x in range(160)]

    def expected(scx):
        out = []
        for x in range(160):
            wx = (x + scx) & 255
            out.append(1 if wx % 8 == bars(wx // 8) else 0)
        return out

    def find_shift(pixels):
        hits = [s for s in range(256) if expected(s) == pixels]
        return hits

    sh = m.shades()
    top = find_shift(row_pixels(sh, 20))
    bottom = find_shift(row_pixels(sh, 110))
    assert len(top) == 1 and len(bottom) == 1, (top, bottom)
    near, far = bottom[0], top[0]
    assert m[m.sym['wCamX']] - near in range(-1, 3) or (m[m.sym['wCamX']] - near) % 256 in (0, 1, 2), (m[m.sym['wCamX']], near)
    assert (far - (near // 2)) % 256 in (255, 0, 1), (far, near)       # far layer moves at half speed
    m.stop()


# ---------------------------------------------------------------- chapter 8
@test
def text_demo():
    m = Machine('text_demo', BOOT + 200)
    mp = lambda c, r, base=0x9800: m[base + r * 32 + c]
    text = lambda c, r, n, base=0x9800: ''.join(chr(mp(c + i, r, base)) for i in range(n))
    assert text(2, 2, 16) == 'HELLO, GAME BOY!', text(2, 2, 16)
    assert text(2, 4, 9) == 'SCORE 042', text(2, 4, 9)
    assert [mp(c, 6) for c in range(2, 7)] == [1, 1, 1, 2, 3]
    assert mp(0, 0) == 0x20 and mp(19, 17) == 0x20
    # the window box: frame top and bottom, the message typed on row 1
    assert [mp(c, 0, 0x9C00) for c in range(20)] == [4] * 20
    assert text(2, 1, 19, 0x9C00) == 'TEXT IS JUST TILES.', text(2, 1, 19, 0x9C00)
    assert [mp(c, 3, 0x9C00) for c in range(1, 19)] == [4] * 18
    assert m[0xFF4A] == 112
    # the font tile for 'A' is the glyph's rows, doubled into both bit-planes
    glyph = font_rows()[ord('A')]
    assert m.read(0x8000 + ord('A') * 16, 16) == [b for g in glyph for b in (g, g)]
    sh = m.shades()
    assert any(sh[2 * 8 + r][2 * 8 + c] == 3 for r in range(8) for c in range(8)), "'H' on screen"
    m.stop()


# ---------------------------------------------------------------- chapter 9
@test
def anim_demo():
    m = Machine('anim_demo', BOOT)
    s = m.sym
    t0 = m[s['wTicks']]
    m.run(10)
    assert (m[s['wTicks']] - t0) % 256 == 10, 'one tick per frame'
    for _ in range(600):                       # the ball always stays on screen and bounces
        m.run(1)
        x, y = m[s['wBallX']], m[s['wBallY']]
        assert 1 <= x <= 152 and 1 <= y <= 136, (x, y)
    # the counter on screen is the tick count, at most two frames behind
    t = m[s['wTicks']]
    shown = int(''.join(chr(m[0x9801 + i]) for i in range(3)))
    assert (t - shown) % 256 in (0, 1, 2), (t, shown)
    # the real OAM entry follows the shadow
    x, y = m[s['wBallX']], m[s['wBallY']]
    oam = m.read(0xFE00, 4)
    assert abs(oam[1] - 8 - x) <= 1 and abs(oam[0] - 16 - y) <= 1 and oam[2] == 1, (oam, x, y)
    assert all(v == 0 for v in m.read(0xFE04, 156)), 'other sprites hidden'
    assert m[s['wQueueLen']] <= 3
    m.stop()


# ---------------------------------------------------------------- chapter 10
@test
def speed_demo():
    m = Machine('speed_demo', BOOT)
    s = m.sym
    t = {k[5:]: m[v] for k, v in s.items() if k.startswith('wTime')}
    assert t['Unrolled'] < t['Copy'] and t['Stack'] < t['Unrolled'], t
    assert t['FillPush'] < t['Fill'], t
    assert t['AddrFast'] < t['Addr'], t
    assert t['Copy'] > 0 and t['FillPush'] > 0
    assert m.read(s['wBuffer'], 1024) == [0x33] * 1024            # the PUSH fill was the last thing to write it
    m.stop()


CHECK = '''
SECTION "CheckVars", WRAM0
wBad:  DS 1
wCopyBad: DS 1
wSrc:  DS 64
wDst:  DS 64
INCLUDE "boot.inc"
    ; map_addr_fast must agree with map_addr for all 32 x 32 positions
    XOR A
    LD [wBad], A
    LD C, 0
.row:
    LD B, 0
.col:
    PUSH BC
    CALL map_addr
    LD D, H
    LD E, L
    POP BC
    PUSH DE
    CALL map_addr_fast
    POP DE
    LD A, H
    CP D
    JR NZ, .bad
    LD A, L
    CP E
    JR Z, .ok
.bad:
    LD A, [wBad]
    INC A
    LD [wBad], A
.ok:
    INC B
    LD A, B
    CP 32
    JR NZ, .col
    INC C
    LD A, C
    CP 32
    JR NZ, .row
    ; both copy routines must reproduce 64 bytes exactly
    LD HL, wSrc
    LD B, 64
    LD A, 7
.make:
    LD [HL+], A
    ADD 37
    DEC B
    JR NZ, .make
    XOR A
    LD [wCopyBad], A
    LD HL, wSrc
    LD DE, wDst
    LD B, 4
    CALL copy_unrolled
    CALL compare
    LD HL, wDst
    LD BC, 64
    XOR A
    CALL fill_bytes
    LD HL, wSrc
    LD DE, wDst
    LD B, 4
    CALL copy_stack
    EI
    CALL compare
Done:
    HALT
    NOP
    JR Done
compare:
    LD HL, wSrc
    LD DE, wDst
    LD B, 64
.next:
    LD A, [DE]
    CP [HL]
    JR Z, .same
    LD A, [wCopyBad]
    INC A
    LD [wCopyBad], A
.same:
    INC HL
    INC DE
    DEC B
    JR NZ, .next
    RET
INCLUDE "gfx.asm"
INCLUDE "fast.asm"
'''


@test
def fast_routines_agree_with_simple_ones():
    path = f'{TMP}/check.asm'
    os.makedirs(TMP, exist_ok=True)
    open(path, 'w').write(CHECK)
    m = Machine('check', BOOT, src_dir=TMP)
    assert m[m.sym['wBad']] == 0, 'map_addr_fast disagrees with map_addr'
    assert m[m.sym['wCopyBad']] == 0, 'a copy routine corrupted data'
    m.stop()



CHECK_CANVAS = '''
SECTION "CheckVars", WRAM0
wDone: DS 1
INCLUDE "boot.inc"
    XOR A
    CALL canvas_clear
    LD D, 3
    LD B, 200
    LD C, 5
    CALL plot               ; off the right side
    LD B, 5
    LD C, 200
    CALL plot               ; off the bottom
    LD B, 128
    LD C, 0
    CALL plot               ; exactly one past the edge
    LD B, 255
    LD C, 255
    CALL toggle_pixel
    LD A, 3
    LD [wColour], A
    LD B, 10
    LD C, 10
    LD D, 0
    LD E, 5
    CALL draw_rect          ; no width
    LD B, 10
    LD C, 10
    LD D, 5
    LD E, 0
    CALL draw_rect          ; no height
    LD B, 10
    LD C, 10
    LD D, 5
    LD E, 0
    CALL fill_rect          ; no height
    LD B, 60
    LD C, 60
    LD E, 0
    CALL draw_circle        ; radius 0 = one pixel
    LD B, 100
    LD C, 100
    LD E, 0
    CALL fill_circle
    LD B, 5
    LD C, 5
    LD E, 20
    CALL draw_circle        ; hangs over the top and left edges
    LD B, 120
    LD C, 122
    LD E, 15
    CALL fill_circle        ; hangs over the right and bottom edges
    LD A, 1
    LD [wDone], A
Done:
    HALT
    NOP
    JR Done
INCLUDE "gfx.asm"
INCLUDE "canvas.asm"
'''


@test
def canvas_edges_and_degenerate_shapes():
    open(f'{TMP}/check_canvas.asm', 'w').write(CHECK_CANVAS)
    m = Machine('check_canvas', BOOT, src_dir=TMP)
    assert m[m.sym['wDone']] == 1, 'the routines hung or crashed'
    got = canvas_pixels(m)
    want = [[0] * 128 for _ in range(128)]
    model_circle(want, 60, 60, 0, 3)
    model_circle(want, 100, 100, 0, 3, fill=True)
    model_circle(want, 5, 5, 20, 3)
    model_circle(want, 120, 122, 15, 3, fill=True)
    bad = [(x, y) for y in range(128) for x in range(128) if got[y][x] != want[y][x]]
    assert not bad, f'{len(bad)} pixels differ, e.g. {bad[:5]}'
    assert got[60][60] == 3 and got[100][100] == 3
    m.stop()


CHECK_QUEUE = '''
SECTION "CheckVars", WRAM0
wIEAfter: DS 1
INCLUDE "boot.inc"
    CALL oam_init
    LD A, %00000101         ; some interrupts enabled (IME stays off: nothing will fire)
    LDH [rIE], A
    XOR A
    LD [wQueueLen], A
    LD A, "A"
    LD B, 3
    LD C, 4
    CALL queue_tile
    LD A, "B"
    LD B, 4
    LD C, 4
    CALL queue_tile
    LDH A, [rIE]
    LD [wIEAfter], A
Done:
    HALT
    NOP
    JR Done
INCLUDE "gfx.asm"
INCLUDE "oam.asm"
INCLUDE "vblank.asm"
'''


@test
def queue_tile_preserves_interrupt_enable():
    open(f'{TMP}/check_queue.asm', 'w').write(CHECK_QUEUE.replace('"A"', "'A'").replace('"B"', "'B'"))
    m = Machine('check_queue', BOOT, src_dir=TMP)
    s = m.sym
    assert m[s['wIEAfter']] == 0b00000101, 'rIE must be put back exactly as it was'
    assert m[s['wQueueLen']] == 2
    q = m.read(s['wQueue'], 6)
    assert q == [0x83, 0x98, ord('A'), 0x84, 0x98, ord('B')] or q == [3 + 4 * 32, 0x98, 65, 4 + 4 * 32, 0x98, 66], q
    m.stop()


@test
def profile_build_shows_the_cost_of_a_frame():
    def black_rows(defines):
        m = Machine('anim_demo', BOOT + 50, defines=defines)
        sh = m.shades()
        m.stop()
        return [y for y in range(144) if all(v == 3 for v in sh[y])]
    assert black_rows(()) == [], 'normal build: no black band'
    band = black_rows(('PROFILE=1',))
    assert band and band == list(range(band[0], band[-1] + 1)) and band[0] == 0, band[:5]
    assert 8 <= len(band) <= 20, f'the work overruns VBlank by about 14 lines, measured {len(band)}'


@test
def walker_demo():
    m = Machine('walker_demo', BOOT)
    s = m.sym
    pos = lambda: (m[s['wPX']], m[s['wPY']])
    press, release, button = m.pb.button_press, m.pb.button_release, m.pb.button
    assert m[0xFF40] & 0b100, 'sprites are 8x16'
    x0, y0 = pos()
    sh = m.shades()
    assert sh[y0 + 3][x0 + 3] == 3 and sh[y0 + 10][x0 + 3] == 3, 'both halves of the tall sprite are drawn'
    press('right'); m.run(20); release('right')
    assert pos()[0] - x0 == 20, 'one pixel a frame'
    press('down'); press('b'); m.run(10); release('down'); release('b')
    assert pos()[1] - y0 == 20, 'two pixels a frame while B is held'
    # collision: the wall across the middle is column 10 (pixels 80-87); the box is 8 wide
    press('right'); m.run(120); release('right')
    assert pos()[0] == 72, f'stopped against the middle wall, at {pos()[0]}'
    press('up'); m.run(120); release('up')
    assert pos()[1] == 8, 'stopped under the top wall (row 0)'
    press('right'); m.run(200); release('right')
    assert pos()[0] == 144, 'above the middle wall the way is clear, up to the right wall'
    press('down'); m.run(200); release('down')
    assert pos()[1] == 18 * 8 - 8 - 16, 'stopped on the bottom wall'
    press('up'); m.run(56); release('up')          # up to y = 64, level with the middle wall
    press('left'); m.run(300); release('left')
    assert pos()[0] == 88, f'stopped against the other side of the middle wall, at {pos()[0]}'
    # walking animation: the tile pair changes as steps are taken
    m.run(5)
    tiles = set()
    press('up')
    for _ in range(40):
        m.run(1)
        tiles.add(m.read(0xFE00, 4)[2])
    release('up')
    assert tiles == {4, 6}, tiles
    # A turns the player round, once per press
    f = m[s['wFlags']]
    button('a'); m.run(8)
    assert m[s['wFlags']] == f ^ 0x20
    m.run(30)
    assert m[s['wFlags']] == f ^ 0x20, 'holding nothing does not turn it again'
    assert m.read(0xFE00, 4)[3] & 0x20
    m.stop()


@test
def scroll2d_demo():
    def tile(c, r):
        if ((c ^ r) >> 2) & 1:
            return 1
        return 2 if c % 4 == 1 and r % 4 == 1 else 0
    m = Machine('scroll2d_demo', BOOT)
    s = m.sym
    phases = set()
    for _ in range(40):
        cx, cy = m[s['wCamX']], m[s['wCamY']]
        phases.add(m[s['wPhase']])
        assert m[0xFF43] == cx and m[0xFF42] == cy, 'scroll registers follow the camera'
        tx, ty = cx >> 3, cy >> 3
        bad = [(c, r) for c in range(tx, tx + 20) for r in range(ty, ty + 18)
               if m[0x9800 + (r & 31) * 32 + (c & 31)] != tile(c, r)]
        assert not bad, f'camera ({cx},{cy}): {len(bad)} visible tiles differ from the world, e.g. {bad[:3]}'
        m.run(17)
    assert phases == {0, 1, 2, 3}, 'went right, down, left and up'
    m.stop()


# ---------------------------------------------------------------- the book
BOOK = f'{ROOT}/gameboy_graphics.html'


@test
def book_is_up_to_date():
    assert open(BOOK).read() == build_book.build(), 'run: python3 tests/build_book.py'


@test
def book_standalone_and_links_work():
    html_text = open(BOOK).read()
    low = re.sub(r'data:[\w/+.-]+;base64,[A-Za-z0-9+/=]+', '', html_text).lower()   # (not the embedded images)
    for word in ('spectrum', 'zx ', 'z80', 'norbert', 'norbsoft'):
        assert word not in low, f'the book must stand alone, but mentions {word!r}'
    ids = set(re.findall(r'id="([^"]+)"', html_text))
    assert len(ids) == len(re.findall(r'id="([^"]+)"', html_text)), 'duplicate ids'
    missing = [h for h in re.findall(r'href="#([^"]+)"', html_text) if h not in ids]
    assert not missing, missing
    for n in range(1, 12):
        assert re.search(rf'<h1 id="[^"]+">{n}\. ', html_text), f'chapter {n} missing'


@test
def book_screenshots_match_the_programs():
    """Every PNG in book_src/img is what its program shows now, and every one is used in the book."""
    sys.path.insert(0, os.path.join(os.path.dirname(BOOK), 'tools'))
    import screenshots
    from PIL import Image, ImageChops
    used = set(re.findall(r'\[\[shot (\w+) \|', build_book.source_text()))
    assert used == set(screenshots.SHOTS), used ^ set(screenshots.SHOTS)
    for name in sorted(used):
        old = Image.open(f'{screenshots.OUT}/{name}.png').convert('RGB')
        assert ImageChops.difference(old, screenshots.render(name)).getbbox() is None, \
            f'{name}.png is out of date: run tools/screenshots.py'


@test
def book_listings_are_the_tested_files():
    """Every [[file x]] / [[part x | a | b]] marker in the sources must point at a real file."""
    src = build_book.source_text()
    for name in re.findall(r'\[\[file ([\w.]+)\]\]', src):
        build_book.read_source(name)
    n_files = len(re.findall(r'\[\[file ', src)) + len(re.findall(r'\[\[part ', src))
    assert n_files >= 28, n_files


def luminance(hexcolour):
    r, g, b = (int(hexcolour[i:i + 2], 16) / 255 for i in (1, 3, 5))
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


@test
def book_colours_are_readable():
    css = open(f'{ROOT}/book_src/00-head.html').read()
    var = dict(re.findall(r'--([\w-]+):\s*(#[0-9a-fA-F]{6})', css))
    pairs = [('text', 'bg'), ('text-dim', 'bg'), ('text', 'surface'), ('text-dim', 'surface'), ('link', 'bg'),
             ('link', 'surface'), ('heading', 'bg'), ('code-text', 'code-bg'), ('code-comment', 'code-bg'),
             ('code-keyword', 'code-bg'), ('code-label', 'code-bg'), ('code-string', 'code-bg'),
             ('code-number', 'code-bg'), ('code-directive', 'code-bg'), ('inline-code-text', 'inline-code-bg')]
    for fg, bg in pairs:
        a, b = sorted((luminance(var[fg]), luminance(var[bg])), reverse=True)
        ratio = (a + 0.05) / (b + 0.05)
        assert ratio >= 4.5, f'{fg} on {bg}: contrast {ratio:.2f}'


# ---------------------------------------------------------------- runner
if __name__ == '__main__':
    wanted = sys.argv[1:]
    todo = [t for t in TESTS if not wanted or t.__name__ in wanted]
    failed = 0
    for t in todo:
        try:
            t()
            print(f'ok    {t.__name__}')
        except Exception:
            failed += 1
            print(f'FAIL  {t.__name__}')
            traceback.print_exc(limit=3)
    print(f'\n{len(todo) - failed} passed, {failed} failed')
    sys.exit(1 if failed else 0)
