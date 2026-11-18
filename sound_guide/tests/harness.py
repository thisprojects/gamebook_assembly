"""Shared helpers: assemble a program with RGBDS and run it headless in PyBoy, capturing its sound."""
import os, re, shutil, subprocess, sys, tempfile, warnings
warnings.filterwarnings('ignore')
os.environ.setdefault('SDL_VIDEODRIVER', 'dummy')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = f'{ROOT}/lib'
EXAMPLES = f'{ROOT}/examples'
TMP = tempfile.mkdtemp(prefix='gbsnd_')


def tool(name):
    local = f'{ROOT}/tools/rgbds/{name}'
    found = local if os.path.exists(local) else shutil.which(name)
    if not found:
        sys.exit(f'{name} not found: install RGBDS')
    return found


def build(name, cgb=False, src_dir=EXAMPLES, defines=()):
    """Assemble <src_dir>/<name>.asm exactly as the book says.  Any warning is a failure.
    Returns (rom path, symbols {label: address})."""
    path = f'{src_dir}/{name}.asm'
    obj, rom, sym = f'{TMP}/{name}.o', f'{TMP}/{name}.gb', f'{TMP}/{name}.sym'
    fix = [tool('rgbfix'), '-v', '-p', '0xFF', '-t', name[:11].upper()] + (['-c'] if cgb else []) + [rom]
    for cmd in ([tool('rgbasm'), '-I', f'{LIB}/', '-I', f'{src_dir}/'] + [f'-D{d}' for d in defines] + ['-o', obj, path],
                [tool('rgblink'), '-n', sym, '-o', rom, obj], fix):
        r = subprocess.run(cmd, capture_output=True, text=True)
        assert r.returncode == 0 and not r.stderr.strip(), f'{os.path.basename(cmd[0])}: {r.stdout}{r.stderr}'
    symbols = {}
    for line in open(sym):
        m = re.match(r'([0-9A-Fa-f]{2}):([0-9A-Fa-f]{4}) (\S+)', line)
        if m:
            symbols[m.group(3)] = int(m.group(2), 16)
    return rom, symbols


class Machine:
    """A running Game Boy.  Memory is read with m[addr] / m.read(addr, n)."""
    def __init__(self, name, frames=120, cgb=False, src_dir=EXAMPLES, defines=(), record_from=None):
        from pyboy import PyBoy
        self.rom, self.sym = build(name, cgb=cgb, src_dir=src_dir, defines=defines)
        self.pb = PyBoy(self.rom, window='null', sound_emulated=True, cgb=cgb)
        self.frame = 0
        self.record_from = record_from      # start keeping the audio at this frame (None: never)
        self.chunks = []
        self.run(frames)

    def run(self, frames):
        for _ in range(frames):
            self.pb.tick()
            self.frame += 1
            if self.record_from is not None and self.frame > self.record_from:
                self.chunks.append(self.pb.sound.ndarray.astype('float32').mean(axis=1) / 128.0)

    def audio(self):
        """Everything recorded so far as one mono array in -1..1 at SAMPLE_RATE, and the number of
        samples per frame (the audio of frame n starts at sample n * per_frame)."""
        import numpy as np
        return np.concatenate(self.chunks) if self.chunks else np.zeros(0)

    def __getitem__(self, addr):
        return self.pb.memory[addr]

    def read(self, addr, n):
        return [self.pb.memory[addr + i] for i in range(n)]

    def word(self, addr):
        return self[addr] | self[addr + 1] << 8

    def screen(self):
        """160x144 list of rows, each a list of (r,g,b)."""
        arr = self.pb.screen.ndarray
        return [[tuple(int(v) for v in px[:3]) for px in row] for row in arr]

    def shades(self):
        """Screen as 0 (lightest) .. 3 (darkest), judged by brightness."""
        out = []
        for row in self.screen():
            out.append([min(3, max(0, round((255 - sum(px) / 3) / 85))) for px in row])
        return out

    def stop(self):
        self.pb.stop(save=False)


SAMPLE_RATE = 48000


def tile_rows(vram_bytes):
    """Decode one 16-byte tile into 8 rows of 8 colours."""
    rows = []
    for r in range(8):
        lo, hi = vram_bytes[2 * r], vram_bytes[2 * r + 1]
        rows.append([((lo >> (7 - c)) & 1) | (((hi >> (7 - c)) & 1) << 1) for c in range(8)])
    return rows
