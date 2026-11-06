"""Tests for gameboy_lib/*.asm and gameboy_examples/*.asm: assemble every file with RGBDS, then run it
on an emulated Game Boy (PyBoy, headless) and check what appears on screen.  See gameboy_tests/README.md."""
import os, re, shutil, subprocess, sys, tempfile, warnings
warnings.filterwarnings('ignore')
os.environ.setdefault('SDL_VIDEODRIVER', 'dummy')
from pyboy import PyBoy

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = f'{ROOT}/gameboy_lib'
EXAMPLES = f'{ROOT}/gameboy_examples'
BOOK = f'{ROOT}/gameboy_book.html'
Z80_BOOK = f'{ROOT}/z80_book.html'
TMP = tempfile.mkdtemp(prefix='gbbeginners_')


def tool(name):
    """Find an RGBDS tool: tools/rgbds/ in this project first, then PATH."""
    local = f'{ROOT}/tools/rgbds/{name}'
    found = local if os.path.exists(local) else shutil.which(name)
    if not found:
        sys.exit(f'{name} not found: install RGBDS (see gameboy_tests/README.md)')
    return found


# ---- assembling -------------------------------------------------------------
def build(name, src_dir=LIB, source=None):
    """Assemble <src_dir>/<name>.asm exactly as the book says (rgbasm, rgblink, rgbfix).
    With `source`, assemble that text instead (as if it were <name>.asm in src_dir).
    Returns (rom bytes, symbol table {label: address}).  Any warning is a failure."""
    path = f'{src_dir}/{name}.asm'
    if source is not None:
        path = f'{TMP}/{name}.asm'
        open(path, 'w').write(source)
    obj, rom, sym = f'{TMP}/{name}.o', f'{TMP}/{name}.gb', f'{TMP}/{name}.sym'
    for cmd in ([tool('rgbasm'), '-I', f'{LIB}/', '-I', f'{src_dir}/', '-o', obj, path],
                [tool('rgblink'), '-n', sym, '-o', rom, obj],
                [tool('rgbfix'), '-v', '-p', '0xFF', '-t', name[:11].upper(), rom]):
        r = subprocess.run(cmd, capture_output=True, text=True)
        assert r.returncode == 0 and not r.stderr.strip(), f'{" ".join(cmd[:1])}: {r.stdout}{r.stderr}'
    symbols = {}
    for line in open(sym):
        m = re.match(r'([0-9A-Fa-f]{2}):([0-9A-Fa-f]{4}) (\S+)', line)
        if m: symbols[m.group(3)] = int(m.group(2), 16)
    return open(rom, 'rb').read(), symbols


BOILERPLATE = '''INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]
    NOP
    JP Start
    DS $150 - @, 0

SECTION "Main", ROM0[$150]
Start:
'''
DONE = '\nDone:\n    HALT\n    NOP\n    JR Done\n'


def wrapper(name, extra=(), init='', body=''):
    """For include-only files: a tiny program that INCLUDEs them (and optionally runs `init`), then
    spins at Done, so a test can load registers, CALL a routine and read the result back."""
    # a plain JR spin, not HALT: a halted CPU would ignore a test that jumps it somewhere else
    src = BOILERPLATE + init + '\n    DI\nDone:\n    JR Done\n' + body
    src += ''.join(f'\n    INCLUDE "{e}.asm"\n' for e in (*extra, name))
    return src


# ---- the machine --------------------------------------------------------------
class GameBoy:
    """One emulated DMG running a ROM.  Time is counted in frames (1/60 s)."""

    def __init__(self, rom, symbols, sound=False, hold=()):
        path = f'{TMP}/rom_{id(self)}.gb'
        open(path, 'wb').write(rom)
        self.pb = PyBoy(path, window='null', sound_emulated=sound, sound_volume=100, cgb=False)
        if not sound: self.pb.set_emulation_speed(0)      # fast-forward disables audio sampling
        self.sym = symbols
        for b in hold: self.pb.button_press(b)       # held down from power-on
        self.mem = self.pb.memory
        self.regs = self.pb.register_file
        # PyBoy starts with the Game Boy boot ROM (the scrolling logo); run it until the cartridge starts at $0100
        booted = []
        self.pb.hook_register(0, 0x0100, lambda ctx: booted.append(1), None)
        for _ in range(600):
            if booted: break
            self.pb.tick(1, False)
        assert booted, 'boot ROM never handed over to the cartridge'
        self.pb.hook_deregister(0, 0x0100)
        self.frames = 0

    @property
    def at_done(self):
        """True once the CPU is parked in the program's Done loop (HALT / NOP / JR Done)."""
        d = self.sym.get('Done')
        return d is not None and d <= self.regs.PC < d + 4

    def tick(self):
        self.pb.tick(1, False)
        self.frames += 1

    def run(self, max_frames=3000, each_frame=None):
        """Run until the program reaches its `Done` label; fail if it never does."""
        while not self.at_done:
            assert self.frames <= max_frames, f'program never reached Done (pc={self.regs.PC:#06x})'
            if each_frame: each_frame(self)
            self.tick()
        return self.frames

    def call(self, label, **regs):
        """CALL a routine with the given registers; returns when it RETs to Done."""
        r = self.regs
        for k, v in regs.items(): setattr(r, k.upper(), v)
        r.SP = 0xDFF0
        done = self.sym['Done']
        self.mem[r.SP - 2] = done & 0xFF
        self.mem[r.SP - 1] = done >> 8
        r.SP -= 2
        r.PC = self.sym[label]
        n = 0
        while True:
            self.tick(); n += 1
            if self.at_done: break
            assert n < 200, f'{label} never returned'
        return self

    def rd(self, addr): return self.mem[addr]

    @property
    def bc(self): return self.regs.B << 8 | self.regs.C

    @property
    def de(self): return self.regs.D << 8 | self.regs.E

    def text(self):
        """The 20x18 character screen, read back from the background tile map.  Tile number = ASCII code."""
        out = []
        for row in range(18):
            base = 0x9800 + row * 32
            out.append(''.join(chr(self.mem[base + c]) if self.mem[base + c] >= 32 else '?' for c in range(20)).rstrip())
        while out and not out[-1]: out.pop()
        return out

    def stop(self): self.pb.stop(save=False)


def run_program(name, src_dir=LIB, **kw):
    rom, sym = build(name, src_dir)
    gb = GameBoy(rom, sym, kw.pop('sound', False))
    gb.run(**kw)
    return gb


RESULTS = []
def test(fn):
    try:
        fn(); RESULTS.append((fn.__name__, True, ''))
    except Exception as e:
        import traceback
        RESULTS.append((fn.__name__, False, f'{type(e).__name__}: {e}\n{traceback.format_exc(limit=3)}'))
    return fn


PROGRAMS = ['first', 'example1', 'variables', 'conditionals', 'bitwise', 'loops', 'counter', 'test',
            'print_a_char', 'print_hello', 'print_at', 'print_block', 'wait_key', 'beep']
ROUTINES = {'debug_output': (), 'divide': (), 'assert_a_equals': ('debug_output',)}
# examples/ holds copies of lib/ files under the book's other names (as in the Z80 repo)
EXAMPLE_TWINS = {'first': 'first', 'debug_output': 'debug_output', 'example1': 'example1',
                 'load_example': 'variables', 'flash': 'bitwise', 'conditionals': 'conditionals', 'loops': 'loops'}


# ---- assembly ---------------------------------------------------------------
@test
def every_file_assembles_cleanly():
    files = sorted(f[:-4] for f in os.listdir(LIB) if f.endswith('.asm'))
    assert set(files) == set(PROGRAMS) | set(ROUTINES), set(files) ^ (set(PROGRAMS) | set(ROUTINES))
    for name in PROGRAMS:
        rom, sym = build(name)
        assert len(rom) == 32768, f'{name}: ROM should be padded to 32 KB'
        assert rom[0x100:0x104] == b'\x00\xC3\x50\x01', f'{name}: entry point at $100 should be NOP / JP $0150'
        assert 'Start' in sym and 'Done' in sym, name
    for name, extra in ROUTINES.items():
        build(f'wrap_{name}', source=wrapper(name, extra))

@test
def examples_match_lib():
    for ex, lib in EXAMPLE_TWINS.items():
        a = open(f'{EXAMPLES}/{ex}.asm').read().strip()
        b = open(f'{LIB}/{lib}.asm').read().strip()
        assert a == b, f'examples/{ex}.asm differs from lib/{lib}.asm'
        if lib not in ROUTINES:
            build(ex, EXAMPLES)

# ---- programs ---------------------------------------------------------------
@test
def first():
    assert run_program('first').text() == ['*']

@test
def example1():
    assert run_program('example1').text() == ['Hello!', '42', '*']

@test
def variables():
    assert run_program('variables').text() == ['my_byte:   42', 'my_string: Hello', 'my_array:  1 2 3 4 5']

@test
def conditionals():
    rom, sym = build('conditionals')
    gb = GameBoy(rom, sym); gb.run()
    assert gb.text() == ['a equals 10'] and gb.rd(sym['var_b']) == 1
    # the else branch: patch the constant var_a in the ROM image
    patched = bytearray(rom); patched[sym['var_a']] = 7
    gb = GameBoy(bytes(patched), sym); gb.run()
    assert gb.text() == ['a is not 10'] and gb.rd(sym['var_b']) == 0

@test
def bitwise():
    gb = run_program('bitwise')
    assert gb.text() == ['INVERT!']
    assert gb.rd(0xFF47) == 0b00100111, 'OR set the low two bits, AND cleared the top two, the middle four are untouched'
    assert gb.rd(0xFF47) & 0b00111100 == 0b11100100 & 0b00111100, 'bits 5-2 never disturbed'
    # white letters on a black screen: shade 0 for the text colour, shade 3 for the background
    assert (gb.rd(0xFF47) >> 6) == 0 and (gb.rd(0xFF47) & 3) == 3

@test
def loops():
    rom, sym = build('loops')
    gb = GameBoy(rom, sym)
    seen = []
    def sample(g):
        v = g.rd(0xFF47)
        if not seen or seen[-1] != v: seen.append(v)
    frames = gb.run(each_frame=sample)
    assert seen[-4:] == [0x00, 0x55, 0xAA, 0xFF], [hex(v) for v in seen]
    # 65536 steps of 7 machine cycles at 1048576 cycles/s = 0.437 s = 26 frames per shade
    assert 4 * 26 - 6 <= frames <= 4 * 26 + 6, f'about 26 frames per shade expected, got {frames} in total'

@test
def counter():
    t = run_program('counter').text()
    assert t[0] == 'Counting 0 to 20:', t
    numbers = ' '.join(' '.join(l.split()) for l in t[1:-1]).split()   # the number line wraps at 20 columns
    assert numbers == [str(i) for i in range(21)], numbers
    assert t[-1] == 'Verification PASSED', t

@test
def test_program():
    assert run_program('test').text() == ['Debug output test', '42', 'Test PASSED']

@test
def print_a_char():
    assert run_program('print_a_char').text() == ['A']

@test
def print_hello():
    assert run_program('print_hello').text() == ['Hello from Game Boy']

@test
def print_at():
    t = run_program('print_at').text()
    assert len(t) == 11 and t[10] == ' ' * 5 + 'X' and not any(t[:10]), t     # row 10, column 5

@test
def print_block():
    assert run_program('print_block').text() == ['Printed with one CAL', 'L!']      # wraps at 20 columns

@test
def wait_key():
    rom, sym = build('wait_key')
    for button, shown in (('a', 'A'), ('b', 'B')):
        gb = GameBoy(rom, sym)
        for _ in range(10): gb.tick()
        assert gb.text() == ['Press A or B:'], gb.text()
        assert not gb.at_done, 'must keep waiting until a button is pressed'
        gb.pb.button_press(button)
        gb.run(max_frames=60)
        assert gb.text() == [f'Press A or B: {shown}'], gb.text()
        gb.stop()
    # buttons in the other group (the D-pad) must be ignored
    gb = GameBoy(rom, sym)
    gb.pb.button_press('up')
    for _ in range(20): gb.tick()
    assert not gb.at_done

@test
def beep():
    rom, sym = build('beep')
    gb = GameBoy(rom, sym, sound=True)    # the sound registers only exist when sound is emulated
    gb.run(max_frames=200)
    # PyBoy's audio output is not assertable here, so check what the program wrote to the sound registers.
    # (NR13 is write-only, so the pitch cannot be read back.)
    assert gb.rd(0xFF26) & 0x80, 'master sound on (NR52 bit 7)'
    assert gb.rd(0xFF24) == 0x77 and gb.rd(0xFF25) == 0xFF, 'master volume and panning set'
    assert gb.rd(0xFF11) & 0xC0 == 0x80, 'NR11: 50% duty'
    assert gb.rd(0xFF12) == 0xF3, 'NR12: full volume, fading'
    assert gb.rd(0xFF14) & 0x07 == 0x07, 'NR14: pitch high bits'
    assert 28 <= gb.frames <= 36, f'about 30 frames expected, got {gb.frames}'

# ---- reusable routines -------------------------------------------------------
def routine_gb(name, extra=(), init=''):
    rom, sym = build(f'wrap_{name}', source=wrapper(name, extra, init))
    gb = GameBoy(rom, sym); gb.run()
    return gb

@test
def debug_output():
    gb = routine_gb('debug_output', (), '    CALL debug_init')
    for v in (0, 1, 9, 10, 42, 99, 100, 199, 200, 255):
        gb.call('debug_init'); gb.call('print_number', a=v)
        assert gb.text() == [str(v)], (v, gb.text())
    gb.call('debug_init'); gb.call('set_cursor', b=3, c=4); gb.call('print_char', a=ord('Z'))
    assert gb.text() == ['', '', '', '    Z']
    gb.call('debug_init')
    for i, c in enumerate('Hi there'): gb.mem[0xC800 + i] = ord(c)
    gb.mem[0xC808] = 0
    gb.call('print_string', hl=0xC800)
    assert gb.text() == ['Hi there']
    gb.call('debug_init'); gb.mem[0xC800] = 0; gb.call('print_string', hl=0xC800)
    assert gb.text() == []
    # newline, wrap at 20 columns and wrap back to the top
    gb.call('debug_init')
    for c in 'ab\rcd': gb.call('print_char', a=ord(c))
    assert gb.text() == ['ab', 'cd']
    gb.call('debug_init')
    for _ in range(25): gb.call('print_char', a=ord('x'))
    assert gb.text() == ['x' * 20, 'x' * 5]
    gb.call('debug_init')
    for _ in range(18): gb.call('print_char', a=13)
    gb.call('print_char', a=ord('T'))
    assert gb.text() == ['T'], 'after the last row the cursor wraps to the top'
    # print_char keeps BC, DE, HL; print_number keeps BC
    gb.call('debug_init')
    gb.call('print_char', a=ord('q'), b=1, c=2, d=3, e=4, hl=0x5678)
    r = gb.regs
    assert (r.B, r.C, r.D, r.E, r.HL) == (1, 2, 3, 4, 0x5678)
    gb.call('print_number', a=200, b=7, c=8)
    assert (r.B, r.C) == (7, 8)
    # initialisation: palette, LCD on, tile map blanked, sprites hidden
    gb.call('debug_init')
    assert gb.rd(0xFF47) == 0xE4 and gb.rd(0xFF40) == 0x91
    assert gb.rd(0x9800) == 0x20 and gb.rd(0x9BFF) == 0x20
    assert gb.rd(0x8000 + 0x41 * 16 + 14) == gb.rd(0x8000 + 0x41 * 16 + 15), 'font rows are written to both bit planes'
    # RST $10 is wired to print_char
    rom = gb.pb.memory[0x0010:0x0013]
    assert list(rom) == [0xC3, gb.sym['print_char'] & 255, gb.sym['print_char'] >> 8]

@test
def divide():
    gb = routine_gb('divide')
    for a in range(0, 256, 17):
        for b in range(0, 256, 13):
            gb.call('divide', a=a, b=b)
            carry = gb.regs.F >> 4 & 1
            if b == 0:
                assert carry == 1, ('divide by zero must set carry', a)
            else:
                assert carry == 0 and gb.regs.A == a // b, (a, b, gb.regs.A, carry)
    for a, b in [(255, 1), (255, 255), (0, 5), (1, 2), (200, 3), (100, 100)]:
        gb.call('divide', a=a, b=b)
        assert gb.regs.A == a // b and not gb.regs.F & 0x10, (a, b)

@test
def assert_a_equals():
    gb = routine_gb('assert_a_equals', ('debug_output',), '    CALL debug_init')
    gb.call('assert_a_equals', a=7, b=7)
    assert gb.text() == [], 'passing assert prints nothing'
    gb.call('assert_a_equals', a=9, b=7)
    assert gb.text() == ['ASSERT FAIL! A = 9']


# ---- the book: every claim, snippet and listing -------------------------------------------------
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_book

BOOK_SRC = build_book.source_text()
BLOCKS = re.findall(r'\[\[asm\]\]\n?(.*?)\[\[/asm\]\]', BOOK_SRC, re.S)

def block(marker, nth=0):
    """The nth [[asm]] code block in the book that contains `marker` - the very text the reader sees."""
    found = [b for b in BLOCKS if marker in b]
    assert len(found) > nth, f'no code block containing {marker!r} in the book'
    return found[nth]

def split_at(text, marker):
    i = text.index(marker)
    return text[:i], text[i:]

_n = [0]
def program(code, data='', debug=False):
    """Wrap book code in the standard boilerplate (and the debug routines if asked) and return its source."""
    src = BOILERPLATE + ('    CALL debug_init\n' if debug else '') + code + DONE + data
    if debug: src += '\n    INCLUDE "debug_output.asm"\n'
    return src

def run_book(src, max_frames=600, **kw):
    _n[0] += 1
    rom, sym = build(f'snippet{_n[0]}', source=src)
    gb = GameBoy(rom, sym, **kw)
    gb.run(max_frames=max_frames)
    return gb

def assembles(src):
    _n[0] += 1
    try:
        build(f'try{_n[0]}', source=src); return True
    except AssertionError:
        return False

def bytes_of(code):
    """Machine code the assembler produces for `code` placed at the start of the program."""
    _n[0] += 1
    rom, sym = build(f'bytes{_n[0]}', source=BOILERPLATE + code + DONE)
    return rom[sym['Start']:sym['Done']]

@test
def book_loading_and_storing():
    code = block('Loading values')
    data = 'my_byte: DB 42\nmy_array: DB 1, 2, 3, 4, 5\nSECTION "Variables", WRAM0\nmy_counter: DS 1\n'
    gb = run_book(program(code, data))
    sym = gb.sym
    assert gb.rd(sym['my_counter']) == 99, 'LD [HL], 99 stored through the pointer'
    assert gb.regs.A == 99 and gb.regs.HL == sym['my_counter'] + 1, 'LD A,[HL+] loads then advances HL'
    assert gb.regs.B == 10, 'LD B, A copied the 10'
    gb = run_book(program('    LD A, [my_byte]\n    LD HL, my_byte', 'my_byte: DB 42\n'))
    assert gb.regs.A == 42 and gb.regs.HL == gb.sym['my_byte'], 'brackets = contents, no brackets = address'

@test
def book_square_bracket_syntax_and_missing_instructions():
    assert not assembles(program('    LD A, HL'))                       # A is 8 bits, HL is 16
    assert not assembles(program('    DJNZ Start'))                      # no DJNZ on the Game Boy
    assert not assembles(program('    LDIR'))                            # no block copy
    assert not assembles(program('    IN A, [$FE]'))                     # no I/O ports
    assert not assembles(program('    LD IX, $1234'))                    # no index registers
    assert not assembles(program('    JP M, Start'))                     # no sign flag
    assert not assembles(program('    JP PE, Start'))                    # no parity flag
    assert not assembles(program('    ADD HL, B'))                       # cannot add an 8-bit register to HL
    assert not assembles(program('    ADC HL, DE'))                      # no 16-bit ADC
    assert not assembles(program('    CP [var]', 'var: DB 1\n'))         # CP only takes [HL], never a label
    assert not assembles(program('    DEC [var]', 'var: DB 1\n'))
    assert assembles(program('    CP [HL]\n    DEC [HL]\n    ADD HL, DE\n    LD A, [HL+]\n    SWAP A\n    LD A, [var]', 'var: DB 1\n'))
    for phrase in ('no DJNZ', 'no IX/IY', 'CP [var_a]', 'LDIR', 'ADD HL, B'):
        assert phrase in BOOK_SRC, phrase

@test
def book_ldh_and_rst_are_short():
    assert bytes_of('    LDH A, [rLY]') == bytes([0xF0, 0x44]), 'LDH is 2 bytes'
    assert bytes_of('    LD A, [$FF44]') == bytes([0xFA, 0x44, 0xFF]), 'plain LD from $FF44 is 3 bytes'
    assert bytes_of('    RST $10') == bytes([0xD7]) and len(bytes_of('    CALL $0010')) == 3
    assert bytes_of('    RST $38') == bytes([0xFF]), 'RST $38 is $FF, the padding byte'
    assert [bytes_of(f'    RST ${a:02X}')[0] for a in range(0, 0x40, 8)] == [0xC7, 0xCF, 0xD7, 0xDF, 0xE7, 0xEF, 0xF7, 0xFF]
    rom, _ = build('first')
    assert rom[-1] == 0xFF and rom[0x7FFF] == 0xFF, 'rgbfix -p 0xFF pads with $FF (= RST $38)'

@test
def book_xor_swap_and_logic():
    gb = run_book(program('    LD A, 77\n    XOR A'))
    assert gb.regs.A == 0 and gb.regs.F & 0x80, 'XOR A clears A and sets Z'
    assert bytes_of('    XOR A') == bytes([0xAF]) and len(bytes_of('    LD A, 0')) == 2
    gb = run_book(program('    LD A, %11110000\n    SWAP A'))
    assert gb.regs.A == 0b00001111
    gb = run_book(program('    LD A, %00010011\n    SWAP A'))
    assert gb.regs.A == 0b00110001
    gb = run_book(program('    LD A, 3\n    LD B, 5\n    AND B'));  assert gb.regs.A == 1, '3 AND 5 = 1'
    gb = run_book(program('    LD A, 3\n    LD B, 5\n    OR B'));   assert gb.regs.A == 7, '3 OR 5 = 7'
    gb = run_book(program('    LD A, %00110101\n    CPL'));         assert gb.regs.A == 0b11001010
    gb = run_book(program('    LD A, %00000000\n    OR %00100000')); assert gb.regs.A == 0x20
    gb = run_book(program('    LD A, %01000000\n    XOR %01000000')); assert gb.regs.A == 0

@test
def book_expression():
    gb = run_book(program(block('Verify the result using debug output'), debug=True))
    assert gb.text() == ['30']

@test
def book_joypad_snippets():
    # chapter 8: branch on BIT 0
    code = block('BIT 0, A')
    src = program(code + '\n    LD B, 0\n    JR Done\na_pressed:\n    LD B, 1\n')
    rom, sym = build('snip_joy2', source=src)
    for press, expect in ((False, 0), (True, 1)):
        gb = GameBoy(rom, sym, hold=['a'] if press else [])
        gb.run(); assert gb.regs.B == expect, (press, gb.regs.B)
    # the D-pad is the other group
    rom, sym = build('snip_joy3', source=program('    LD A, %00100000\n    LDH [rP1], A\n    LDH A, [rP1]\n    LDH A, [rP1]\n    AND $0F'))
    gb = GameBoy(rom, sym, hold=['up']); gb.run(); assert gb.regs.A == 0b1011, 'Up is bit 2'

@test
def book_16bit_add_examples():
    for marker, b, c in (('Adding 200 + 100', 1, 44), ('Adding 50 + 30', 0, 80)):
        gb = run_book(program(block(marker)))
        assert (gb.regs.B, gb.regs.C) == (b, c), marker
    gb = run_book(program(block('HL = HL + DE using 8-bit instructions')))
    assert gb.regs.HL == 800
    gb = run_book(program('    LD HL, 500\n    LD DE, 300\n    ADD HL, DE'))
    assert gb.regs.HL == 800 and not gb.regs.F & 0x10

@test
def book_flags_cp_and_signed_trick():
    gb = run_book(program('    LD A, 10\n    CP 10'));  assert gb.regs.F & 0x80 and not gb.regs.F & 0x10 and gb.regs.A == 10
    gb = run_book(program('    LD A, 9\n    CP 10'));   assert not gb.regs.F & 0x80 and gb.regs.F & 0x10, 'A < n sets carry'
    gb = run_book(program('    LD A, 11\n    CP 10'));  assert not gb.regs.F & 0x90, 'A > n clears Z and C'
    gb = run_book(program('    LD A, 10\n    SUB 20'));  assert gb.regs.A == 246 and gb.regs.F & 0x10
    gb = run_book(program('    LD A, 200\n    ADD A, 100')); assert gb.regs.A == 44 and gb.regs.F & 0x10
    gb = run_book(program('    LD A, 200\n    BIT 7, A\n    JR NZ, neg\n    LD B, 0\n    JR Done\nneg:\n    LD B, 1')); assert gb.regs.B == 1
    gb = run_book(program('    LD A, 100\n    BIT 7, A\n    JR NZ, neg\n    LD B, 0\n    JR Done\nneg:\n    LD B, 1')); assert gb.regs.B == 0
    # 16-bit INC/DEC do not touch the flags
    gb = run_book(program('    LD A, 1\n    CP 2\n    LD BC, 1\n    DEC BC\n'));    assert gb.regs.F & 0x10 and not gb.regs.F & 0x80, '16-bit DEC leaves Z alone'

@test
def book_if_else_listing_matches_the_program():
    assert 'WRAM0' in open(f'{LIB}/conditionals.asm').read() and 'conditionals.asm' in BOOK_SRC

@test
def book_counted_loop_replaces_djnz():
    code = block('Loop 10 times').replace('    ; ... loop body ...', '    INC E')
    gb = run_book(program('    LD E, 0\n' + code)); assert gb.regs.E == 10
    # B = 0 runs 256 times, B = 1 runs once
    code = block('Loop 10 times').replace('    ; ... loop body ...', '    INC DE').replace('LD B, 10', 'LD B, 0')
    gb = run_book(program('    LD DE, 0\n' + code)); assert gb.de == 256
    gb = run_book(program('    LD DE, 0\n' + code.replace('LD B, 0', 'LD B, 1'))); assert gb.de == 1

@test
def book_while_loops():
    for which in (0, 1):
        code = block('while (a != 0)') if which == 0 else block('Same result, but faster')
        code, tail = split_at(code, 'SECTION') if 'SECTION' in code else (code, '')
        pre = '' if which == 0 else '    LD A, 5\n    LD [var_a], A\n'
        gb = run_book(program(pre + code, tail if tail else 'SECTION "v", WRAM0\nvar_a: DS 1\n'))
        assert gb.rd(gb.sym['var_a']) == 0 and gb.regs.A == 0, which

@test
def book_array_sum():
    for marker, expect in (('Array length — hardcoded', 150), ('B = first byte = 5', 150)):
        code, data = split_at(block(marker), 'my_array:') if marker.startswith('Array') else (block(marker), '')
        if not data:
            data = 'my_array: DB 5, 10, 20, 30, 40, 50\n'
        gb = run_book(program(code, data, debug=True))
        assert gb.text() == [str(expect)], (marker, gb.text())

@test
def book_append_to_array():
    setup = block('Array setup')
    wram, rom = split_at(setup, 'SECTION "Array setup"')
    rom = rom.split('\n', 1)[1]
    code = rom + block('Add 60 to the end of my_array')
    gb = run_book(program(code, wram))
    a = gb.sym['my_array']
    assert [gb.rd(a + i) for i in range(6)] == [4, 10, 20, 30, 60, gb.rd(a + 5)], [gb.rd(a + i) for i in range(6)]
    assert 'DS 9' in setup and '4, 10, 20, 30, 60' in BOOK_SRC

@test
def book_subroutines_and_parameters():
    code, tail = split_at(block('double_it:'), '; Subroutine: doubles')
    gb = run_book(program(code, tail, debug=True)); assert gb.text() == ['10']
    code, tail = split_at(block('add_numbers:'), 'add_numbers:\n')
    gb = run_book(program(code, tail, debug=True)); assert gb.text() == ['30']
    gb = run_book(program('    LD BC, $1234\n    LD DE, $5678\n    PUSH BC\n    PUSH DE\n    LD BC, 0\n    LD DE, 0\n    POP DE\n    POP BC'))
    assert (gb.bc, gb.de) == (0x1234, 0x5678), 'LIFO restore'
    assert gb.regs.SP == 0xFFFE, 'stack starts at $FFFE after the boot ROM'

@test
def book_array_index_and_structures():
    code = block('Access element 3 of the primes array')
    gb = run_book(program(code, 'primes: DB 2, 3, 5, 7, 11, 13, 17, 19, 23, 29\n')); assert gb.regs.A == 7
    layout = block('Player structure layout')
    defs, wram = split_at(layout, 'SECTION')
    for field, off in (('PLAYER_X', 0), ('PLAYER_Y', 1), ('PLAYER_HP', 2), ('PLAYER_SCORE', 3), ('PLAYER_LIVES', 5)):
        assert f'DEF {field}' in defs and f'EQU {off}' in defs
    init = '    LD A, 10\n    LD [player1 + PLAYER_HP], A\n'
    gb = run_book(defs + program(init + block('Read a field'), wram))
    p = gb.sym['player1']
    assert gb.rd(p + 2) == 9 and gb.rd(p + 0) == 100, 'health decremented, x set'
    gb = run_book(defs + program('    LD HL, player1\n' + init + block('HL = pointer to the current player'), wram))
    assert gb.regs.A == 10, 'base + offset via ADD HL, DE'

@test
def book_strings_and_return_codes():
    code, tail = split_at(block('Null-terminated string'), 'greeting:')
    gb = run_book(program(tail.split('\n\n')[1], 'greeting: DB "Hello, World!", 0\n', debug=True))
    assert gb.text() == ['Hello, World!']
    # divide with its caller, both outcomes
    caller = block('Caller checks the result')
    body, tail = split_at(caller, 'handle_error:')
    for a, b, expect in ((84, 2, '42'), (5, 0, 'Error: div by zero!')):
        src = program(f'    LD A, {a}\n    LD B, {b}\n' + body.replace('; Caller checks the result:\n', '') .replace('    JP continue', '    JP Done'),
                      tail.replace('continue:\n', '    JP Done\n') + '\n    INCLUDE "divide.asm"\n', debug=True)
        src = src.replace('\n    JP Done\n\n', '\n    JP Done\n\n')
        gb = run_book(src)
        assert gb.text() == [expect], (a, b, gb.text())

@test
def book_vram_fill_snippet():
    code = block('Fill the Game Boy tile map')
    gb = run_book(program(code, debug=True))
    assert all(gb.rd(0x9800 + i) == ord('A') for i in range(32 * 32))
    assert gb.rd(0xFF40) == 0x91, 'LCD switched back on'
    assert 'damage' in BOOK_SRC, 'the book warns about switching the LCD off outside VBlank'

@test
def book_library_routines_snippet():
    code = block('Move the cursor to row 5, column 2')
    inc = '\n    INCLUDE "debug_output.asm"\n'
    gb = run_book(program(code) + inc)
    assert gb.text() == [], 'the final debug_init clears the screen again'
    keep, _ = split_at(code, '    ; Clear the screen again')
    gb = run_book(program(keep) + inc)
    assert gb.text()[0] == 'A', gb.text()
    assert gb.regs.B == 5 and gb.regs.C == 2

@test
def book_interrupt_handler():
    handler = block('SECTION "VBlank interrupt"')
    enable = block('Forget any interrupt already waiting')
    src = BOILERPLATE + enable + '\n    LD B, 30\nwaiter:\n    HALT\n    NOP\n    DEC B\n    JR NZ, waiter\n' + DONE + '\n' + handler
    gb = run_book(src, max_frames=300)
    n = gb.rd(gb.sym['frame_count'])
    assert 29 <= n <= 32, f'about one VBlank per HALT, counted {n}'
    assert gb.rd(0x40) == 0xC3, 'a JP at the VBlank vector'

@test
def book_interrupt_table_and_rst_table():
    for vec in ('$0040', '$0048', '$0050', '$0058', '$0060'):
        assert vec in BOOK_SRC
    for rst in range(0, 0x40, 8):
        assert f'RST ${rst:02X}' in BOOK_SRC, rst

@test
def book_sound_frequency_formula():
    # NR13/NR14 = $7C0 -> 131072 / (2048 - 0x7C0) = 2048 Hz, as the book says
    assert 131072 / (2048 - 0x7C0) == 2048
    assert 'LD A, $C0' in open(f'{LIB}/beep.asm').read() and 'LD A, $87' in open(f'{LIB}/beep.asm').read()
    assert '2048 Hz' in BOOK_SRC

@test
def book_loop_shade_sequence():
    # loops.asm steps the shade by $55: $00 $55 $AA $FF, and the next step overflows a byte (carry), ending the loop
    seq = [0x55 * i for i in range(4)]
    assert seq == [0x00, 0x55, 0xAA, 0xFF] and 0xFF + 0x55 > 255
    assert '%01010101' in BOOK_SRC and '%10101010' in BOOK_SRC
    # DEC BC leaves Z alone, which is why the delay loop tests B OR C
    gb = run_book(program('    LD A, 1\n    CP 1\n    LD BC, 1\n    DEC BC'))
    assert gb.regs.F & 0x80, 'Z still set from CP: DEC BC did not touch it, although BC is now 0'
    gb = run_book(program('    LD BC, 0\n    DEC BC'))
    assert gb.bc == 0xFFFF, 'BC = 0 counts down through 65535: 65536 steps'

@test
def book_wait_frames_snippet():
    gb = run_book(program(block('Forget any interrupt that is already waiting')), max_frames=200)
    assert 29 <= gb.frames <= 32, f'30 HALTs wait for 30 VBlanks, took {gb.frames} frames'

@test
def book_fonts_and_cursor_math():
    # the cursor -> address arithmetic the book describes: $9800 + row * 32 + column
    gb = routine_gb('debug_output', (), '    CALL debug_init')
    gb.call('debug_init'); gb.call('set_cursor', b=17, c=19); gb.call('print_char', a=ord('Z'))
    assert gb.rd(0x9800 + 17 * 32 + 19) == ord('Z')

def parse_book(path):
    t = open(path).read()
    sections = re.findall(r'<section id="([^"]+)">(.*?)</section>', t, re.S)
    return t, sections

def heading_counts(sec_html):
    return (len(re.findall(r'<h2[ >]', sec_html)), len(re.findall(r'<h3[ >]', sec_html)))

# ---- a beginner's reading order: nothing is used before it has been introduced ----------------------
SECTION_ORDER = ['introduction', 'debug-output-routines', '1-introduction-setup', '2-variables-data-types', '3-operators-expressions',
                 '4-control-flow-conditionals', '5-control-flow-loops', '6-functions', '7-data-structures', '8-input-output',
                 '9-error-handling', '10-debugging-problem-solving', '11-a-complete-project-verified-counter',
                 'rst-instructions-and-library-routines', 'conclusion-what-you-gain']
# Each concept -> the section that introduces it (explains it in prose).  Its first use in a code listing must not come earlier.
INTRODUCED = {
    'introduction': 'LD ADD CALL A B C D E H L AF BC DE HL SP',
    'debug-output-routines': 'RST debug_init print_char',
    '1-introduction-setup': 'INCLUDE SECTION ROM0 NOP JP DS HALT JR',
    '2-variables-data-types': 'DB DW WRAM0 PUSH POP INC print_string print_number',
    '3-operators-expressions': 'SUB DEC AND OR XOR CPL rBGP',
    '4-control-flow-conditionals': 'ADC CP BIT SBC',
    '6-functions': 'RET',
    '7-data-structures': 'DEF EQU',
    '8-input-output': 'LDH rLY rLCDC rP1 set_cursor SWAP',
    '9-error-handling': 'SCF RETI rIF rIE EI',
    'rst-instructions-and-library-routines': 'print_block rNR52 rNR50 rNR51 rNR11 rNR12 rNR13 rNR14 STOP',
}
# words that must appear in the PROSE (outside code listings) of the introducing section
PROSE_REQUIRED = {
    'introduction': ['mnemonic', 'register', 'address', 'ROM', 'RAM', 'label', 'CALL', 'RET', 'comment'],
    'debug-output-routines': ['INCLUDE', 'RST $10', 'debug_init', 'print_string', 'print_number', 'Appendix 1'],
    '1-introduction-setup': ['SECTION', 'NOP', 'JP', 'DS', '@', 'HALT', 'JR', 'Done', 'interrupt', 'boot ROM'],
    '2-variables-data-types': ['null terminator', 'INC', 'PUSH', 'POP', 'stack', 'WRAM0', 'print_string', 'print_number'],
    '3-operators-expressions': ['rBGP', 'palette', 'hardware register', 'OR', 'AND', 'CPL'],
    '4-control-flow-conditionals': ['BIT', 'ADD HL, DE', 'ADC'],
    '5-control-flow-loops': ['DEC BC', 'carry'],
    '8-input-output': ['LDH', 'VBlank', 'rLY', 'rLCDC', 'tile map'],
    '9-error-handling': ['SCF', 'RETI', 'AF', 'rIE', 'rIF', 'HALT'],
}

def code_words(sec_html):
    """Mnemonics, directives, registers, hardware names and routine names used in a section's code listings."""
    words = []
    for pre in re.findall(r'<pre><code>(.*?)</code></pre>', sec_html, re.S):
        import html as _h
        code = _h.unescape(re.sub(r'<[^>]+>', '', pre))
        for line in code.split('\n'):
            line = re.sub(r'"[^"]*"|\'.\'', '', build_book.split_comment(line)[0])     # ignore strings and comments
            words += re.findall(r'[A-Za-z_]\w*', line)
    return words

def prose_of(sec_html):
    import html as _h
    return _h.unescape(re.sub(r'<[^>]+>', ' ', re.sub(r'<pre><code>.*?</code></pre>', ' ', sec_html, flags=re.S)))

@test
def book_introduces_everything_before_using_it():
    _, secs = parse_book(BOOK)
    by_id = dict(secs)
    first = {}                                   # concept -> index of first section whose code uses it (the appendix comes last and is excluded)
    for i, sid in enumerate(SECTION_ORDER):
        for w in code_words(by_id[sid]):
            first.setdefault(w.upper() if w.upper() in build_book.MNEMONICS | build_book.DIRECTIVES else w, i)
    introduced_at = {}
    for sid, words in INTRODUCED.items():
        for w in words.split(): introduced_at[w] = SECTION_ORDER.index(sid)
    for w, i in first.items():
        if w in introduced_at:
            assert i >= introduced_at[w], f'{w} is used in {SECTION_ORDER[i]} but only introduced in {SECTION_ORDER[introduced_at[w]]}'
        elif w.upper() in build_book.MNEMONICS or w in ('LD', ) or re.fullmatch(r'r[A-Z0-9]+', w):
            raise AssertionError(f'{w} (first used in {SECTION_ORDER[i]}) is not in the introduction table')
    # and the prose of each introducing section really does explain it
    for sid, needed in PROSE_REQUIRED.items():
        prose = prose_of(by_id[sid])
        for n in needed:
            assert n in prose, f'{sid}: the text never mentions {n!r}'

@test
def book_early_chapters_stay_beginner_friendly():
    _, secs = parse_book(BOOK)
    by_id = dict(secs)
    # the opening chapters must not lean on ideas that are only explained later
    for sid in ('introduction', 'debug-output-routines', '1-introduction-setup', '2-variables-data-types', '3-operators-expressions'):
        prose = prose_of(by_id[sid])
        code = ' '.join(code_words(by_id[sid]))
        for later in ('OAM', 'sprite', 'VBlank', 'tile map', 'VRAM'):
            assert later not in prose and later not in code, f'{sid} mentions {later!r} before Chapter 8 explains it'
        assert 'LDH' not in code and 'rIE' not in code and 'rIF' not in code, sid
    # the long explanation of the routines is in the appendix, not the opening
    assert len(prose_of(by_id['debug-output-routines'])) < 7000 and len(prose_of(by_id['debug-output-routines'])) < len(prose_of(by_id['appendix-debug-output-routine']))

# ---- the book as a document ------------------------------------------------------------------
def parse_book(path):
    t = open(path).read()
    sections = re.findall(r'<section id="([^"]+)">(.*?)</section>', t, re.S)
    return t, sections

def heading_counts(sec_html):
    return (len(re.findall(r'<h2[ >]', sec_html)), len(re.findall(r'<h3[ >]', sec_html)))

@test
def book_is_up_to_date_with_its_source():
    assert open(BOOK).read() == build_book.build(), 'gameboy_book.html is stale: run python3 gameboy_tests/build_book.py'

@test
def book_listings_are_the_tested_files():
    """Every complete program/library file in the book appears verbatim, because the builder pulls it from gameboy_lib."""
    text = open(BOOK).read()
    used = set(re.findall(r'\[\[file ([\w.]+)\]\]', BOOK_SRC)) | {m.split('|')[0].strip() for m in re.findall(r'\[\[part ([^\]]+)\]\]', BOOK_SRC)}
    needed = {f'{n}.asm' for n in PROGRAMS if n not in ('bitwise',)} | {'bitwise.asm', 'debug_output.asm', 'divide.asm', 'assert_a_equals.asm', 'hardware.inc', 'font.inc'}
    assert needed <= used, f'files missing from the book: {sorted(needed - used)}'
    # highlighted text round-trips: strip tags and unescape, and the file's code is there
    plain = re.sub(r'<[^>]+>', '', text)
    import html as _h
    plain = _h.unescape(plain)
    for name in sorted(needed):
        for line in open(f'{LIB}/{name}').read().split('\n'):
            if line.strip():
                assert line.rstrip() in plain, f'{name}: line missing from the book: {line!r}'

@test
def book_has_every_chapter_of_the_z80_book():
    z_text, z = parse_book(Z80_BOOK)
    g_text, g = parse_book(BOOK)
    assert len(g) == len(z) == 16, (len(g), len(z))
    for (zid, zhtml), (gid, ghtml) in zip(z, g):
        zt = re.search(r'<h1>(.*?)</h1>', zhtml).group(1)
        gt = re.search(r'<h1>(.*?)</h1>', ghtml).group(1)
        assert re.match(r'(\d+\.|)', zt).group(0) == re.match(r'(\d+\.|)', gt).group(0), (zt, gt)
        restructured = gid in ('debug-output-routines', 'appendix-debug-output-routine')   # the debug explanation lives in Appendix 1
        if not restructured:
            assert heading_counts(zhtml) == heading_counts(ghtml), f'{zt}: {heading_counts(zhtml)} headings in the Z80 book, {heading_counts(ghtml)} here'
        assert zhtml.count('<table>') <= ghtml.count('<table>'), zt
        if not restructured:
            assert zhtml.count('<pre>') - 1 <= ghtml.count('<pre>') + 3, f'{zt}: far fewer code blocks than the Z80 book'
    # the explanations the Z80 book gives in its opening chapter are all in Appendix 1 here
    appendix = dict(g)['appendix-debug-output-routine']
    for h in ('debug-init', 'debug-print-char', 'debug-print-string', 'debug-print-number', 'how-to-use-it'):
        assert f'id="{h}"' in appendix, h
    early = dict(g)['debug-output-routines']
    assert 'debug-init' not in early and len(early) < len(appendix) / 2, 'the opening chapter should be short'
    assert 'Appendix 1' in early and 'INCLUDE' in early
    # every Z80 lib/ and examples/ file has a Game Boy counterpart
    assert {f for f in os.listdir(f'{ROOT}/lib') if f.endswith('.asm')} <= {f for f in os.listdir(LIB) if f.endswith('.asm')}
    z_ex = {f for f in os.listdir(f'{ROOT}/examples') if f.endswith('.asm')}
    assert z_ex == {f for f in os.listdir(EXAMPLES) if f.endswith('.asm')}, 'examples/ and gameboy_examples/ differ'
    assert set(os.listdir(f'{ROOT}/tests')) >= {'test_lib.py'} and os.path.exists(f'{ROOT}/gameboy_tests/test_lib.py')

@test
def book_links_and_ids_are_sound():
    t = open(BOOK).read()
    ids = re.findall(r'\bid="([^"]+)"', t)
    assert len(ids) == len(set(ids)), [i for i in ids if ids.count(i) > 1]
    for target in re.findall(r'href="#([^"]+)"', t):
        assert target in ids, f'broken link #{target}'
    toc = re.search(r'<nav id="toc">(.*?)</nav>', t, re.S).group(1)
    toc_targets = re.findall(r'href="#([^"]+)"', toc)
    headings = re.findall(r'<h[123] id="([^"]+)"', t) + re.findall(r'<section id="([^"]+)"', t)
    for h in headings:
        assert h in toc_targets or h.endswith('-example') or h in ('bitwise-try-it', 'loops-try-it', 'loading-storing-example', 'adding-to-an-array',
            'how-to-use-it', 'why-rst-instead-of-call') or h.startswith('example-') , f'heading {h} is not in the contents'

def luminance(hexcolor):
    r, g, b = (int(hexcolor[i:i + 2], 16) / 255 for i in (1, 3, 5))
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)

def contrast(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)

@test
def book_text_is_readable_green_lcd_theme():
    css = open(BOOK).read().split('</style>')[0]
    var = dict(re.findall(r'--([\w-]+):\s*(#[0-9a-fA-F]{6})', css))
    # the DMG palette is really there
    for lcd in ('9bbc0f', '8bac0f', '306230', '0f380f'):
        assert '#' + lcd in css.lower(), lcd
    pairs = [('text', 'bg'), ('text', 'surface'), ('text-dim', 'bg'), ('text-dim', 'surface'), ('heading', 'bg'), ('link', 'bg'), ('link', 'surface'),
             ('code-text', 'code-bg'), ('code-comment', 'code-bg'), ('code-keyword', 'code-bg'), ('code-label', 'code-bg'),
             ('code-string', 'code-bg'), ('code-number', 'code-bg'), ('code-directive', 'code-bg'),
             ('inline-code-text', 'inline-code-bg'), ('lcd-darkest', 'lcd-lightest')]
    for fg, bg in pairs:
        ratio = contrast(var[fg], var[bg])
        assert ratio >= 4.5, f'{fg} on {bg}: contrast {ratio:.2f}:1 is below WCAG AA (4.5:1)'
    # the page really is green: background and surfaces are green hues (G channel dominates)
    for k in ('bg', 'surface', 'code-bg'):
        r, g, b = (int(var[k][i:i + 2], 16) for i in (1, 3, 5))
        assert g > r and g > b, k


if __name__ == '__main__':
    only = sys.argv[1:]
    bad = 0
    for name, ok, msg in RESULTS:
        if only and name not in only: continue
        print(('PASS ' if ok else 'FAIL ') + name + ('' if ok else '  -> ' + msg))
        bad += not ok
    print(f'\n{len(RESULTS) - bad}/{len(RESULTS)} passed')
    sys.exit(1 if bad else 0)
