"""Render the book's figures: run the example programs headless in PyBoy, record their sound and draw it
(or, for the one screenshot, save the screen) as PNGs in book_src/img/.  The book embeds these files.
Every curve in a figure is measured from what the emulated sound chip actually produced, not drawn by hand.

    .venv/bin/python tools/figures.py          (rewrites book_src/img/*.png)
"""
import os, re, sys
import numpy as np
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, f'{ROOT}/tests')
import harness
from harness import SAMPLE_RATE
from PIL import Image, ImageDraw

OUT = f'{ROOT}/book_src/img'
BOOT = 55
SPF = 70224 / 4194304 * SAMPLE_RATE         # audio samples per frame
LIGHT, MID, DARK, PAPER = (155, 188, 15), (139, 172, 15), (15, 56, 15), (173, 203, 44)
LCD_LIGHT, LCD_DARK = (155, 188, 15), (48, 98, 48)


# ---------------------------------------------------------------- recording
def record(name, frames, presses=()):
    """Run a program, recording sound from BOOT on.  Returns (audio, f0): f0 = the frame at which the first sound begins."""
    m = harness.Machine(name, 0, record_from=BOOT)
    m.run(BOOT)
    for f in range(BOOT, frames):
        for at, button in presses:
            if f == at:
                m.pb.button_press(button)
            if f == at + 2:
                m.pb.button_release(button)
        m.run(1)
    a = m.audio()
    m.stop()
    nz = np.nonzero(np.abs(a) > 0.001)[0]
    return a, BOOT + nz[0] / SPF


def frames(a, f0, f1):
    return a[int((f0 - BOOT) * SPF):int((f1 - BOOT) * SPF)]


def rising_edge(seg):
    """Index of the first sample where the wave goes from low to high."""
    hi = seg > 0.5 * seg.max()
    return int(np.nonzero(~hi[:-1] & hi[1:])[0][0]) + 1


def square_hz(seg):
    on = seg > 0.0005
    e = np.nonzero(~on[:-1] & on[1:])[0]
    if len(e) < 3:
        return None
    return (len(e) - 1) * SAMPLE_RATE / (e[-1] - e[0])


# ---------------------------------------------------------------- drawing
def font():
    rows = re.findall(r'db\s+((?:\$[0-9A-F]{2},?\s*){8})', open(f'{ROOT}/lib/font.inc').read(), re.I)
    return {chr(32 + i): [int(x[1:], 16) for x in r.replace(',', ' ').split()] for i, r in enumerate(rows)}


FONT = font()


def text(d, x, y, s, colour=DARK):
    for i, ch in enumerate(s):
        for r, bits in enumerate(FONT.get(ch, FONT['?'])):
            for c in range(8):
                if bits >> (7 - c) & 1:
                    d.point((x + i * 8 + c, y + r), fill=colour)


def canvas(w, h):
    im = Image.new('RGB', (w, h), LIGHT)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, w - 1, h - 1], outline=DARK, width=2)
    return im, d


def trace(d, xs, ys, colour=DARK, width=2):
    d.line(list(zip(xs, ys)), fill=colour, width=width, joint='curve')


def stacked_waves(rows, labels, title, periods_samples, w=640, row_h=84):
    """One waveform per row, each given as an array of samples in -1..1 (or 0..1)."""
    h = 30 + row_h * len(rows)
    im, d = canvas(w, h)
    text(d, 10, 8, title)
    for k, (seg, label) in enumerate(zip(rows, labels)):
        top = 30 + k * row_h
        mid = top + row_h // 2
        d.line([(80, mid), (w - 12, mid)], fill=MID, width=1)
        text(d, 10, mid - 4, label)
        seg = np.asarray(seg, dtype=float)
        lo, hi = seg.min(), seg.max()
        scale = (row_h - 20) / max(hi - lo, 1e-9)
        xs = np.linspace(82, w - 14, len(seg))
        ys = (top + row_h - 10) - (seg - lo) * scale
        trace(d, xs, ys)
    return im


# ---------------------------------------------------------------- the figures
def fig_duty_wave():
    a, f0 = record('duty_demo', 240)
    rows, labels = [], ['12.5%', '25%', '50%', '75%']
    for k in range(4):
        seg = frames(a, f0 + 45 * k + 4, f0 + 45 * k + 30)
        i = rising_edge(seg)
        rows.append(seg[i - 12:i - 12 + round(3 * SAMPLE_RATE / 440)])
    return stacked_waves(rows, labels, 'Duty cycle: three cycles of A4 (440 Hz)', None)


def fig_wave_shapes():
    a, f0 = record('wave_demo', 360)
    rows, labels = [], ['sine', 'triangle', 'saw', 'pulse']
    n = round(2 * SAMPLE_RATE / 220)
    for k in range(4):
        seg = frames(a, f0 + 75 * k + 20, f0 + 75 * k + 50)
        seg = seg - seg.mean()
        rising = np.nonzero((seg[:-1] < 0) & (seg[1:] >= 0))[0]
        i = int(rising[0]) if k != 2 else int(np.nonzero(np.diff(seg) < -0.5 * np.abs(np.diff(seg)).max())[0][0]) + 1
        rows.append(seg[i:i + n])
    return stacked_waves(rows, labels, 'Wave channel: two cycles of A3 (220 Hz)', None)


def fig_envelope_shapes():
    a, f0 = record('envelope_demo', 520)
    labels = ['pluck', 'fade', 'swell', 'steady']
    w, row_h = 640, 70
    im, d = canvas(w, 30 + row_h * 4)
    text(d, 10, 8, 'Envelopes: loudness over two seconds')
    block = round(SAMPLE_RATE * 0.01)
    for k in range(4):
        seg = frames(a, f0 + 120 * k, f0 + 120 * k + 120)
        n = len(seg) // block
        level = [np.abs(seg[i * block:(i + 1) * block]).max() for i in range(n)]
        top = 30 + k * row_h
        base = top + row_h - 8
        d.line([(80, base), (w - 12, base)], fill=MID, width=1)
        text(d, 10, top + row_h // 2 - 4, labels[k])
        xs = np.linspace(82, w - 14, n)
        ys = base - np.array(level) / 0.117 * (row_h - 18)
        trace(d, xs, ys)
    return im


def fig_sweep_pitch():
    a, f0 = record('sweep_demo', 400)
    w, panel = 640, 110
    im, d = canvas(w, 34 + 3 * panel)
    text(d, 10, 8, 'Sweep: pitch over time (log scale)')
    lo, hi = np.log(60), np.log(2300)
    x0, x1 = 90, w - 20
    spans = (0.4, 1.5, 1.5)                       # seconds shown for each effect
    for k, name in enumerate(('jump', 'laser', 'slide')):
        top = 34 + k * panel
        y0, y1 = top + panel - 22, top + 8
        text(d, 10, top + panel // 2 - 4, name)
        for hz in (100, 1000):
            y = y0 - (np.log(hz) - lo) / (hi - lo) * (y0 - y1)
            d.line([(x0, y), (x1, y)], fill=MID, width=1)
            text(d, 40, y - 4, f'{hz}')
        span = spans[k]
        for sec in np.arange(0.25 if k == 0 else 0.5, span + 0.01, 0.25 if k == 0 else 0.5):
            x = x0 + sec / span * (x1 - x0)
            text(d, x - 12, y0 + 8, f'{sec:.2f}s' if k == 0 else f'{sec:.1f}s')
        pts = []
        start = f0 + 90 * k
        for step in range(0, int(span * 59.73) - 2):
            seg = frames(a, start + step, start + step + 3)
            hz = square_hz(seg)
            if hz and np.abs(seg).max() > 0.01 and 60 < hz < 2300:
                pts.append((x0 + step / 59.73 / span * (x1 - x0), y0 - (np.log(hz) - lo) / (hi - lo) * (y0 - y1)))
        trace(d, [p[0] for p in pts], [p[1] for p in pts])
    return im


def shot_instrument():
    m = harness.Machine('instrument_demo', 0)
    m.run(70)
    m.pb.button_press('a')
    m.run(3)
    m.pb.button_release('a')
    m.run(4)
    img = Image.fromarray(m.pb.screen.ndarray[:, :, :3].copy())
    m.stop()
    return img.resize((img.width * 3, img.height * 3), Image.NEAREST)


FIGURES = {
    'duty_wave': fig_duty_wave,
    'envelope_shapes': fig_envelope_shapes,
    'sweep_pitch': fig_sweep_pitch,
    'wave_shapes': fig_wave_shapes,
    'instrument_demo': shot_instrument,
}


def render(name):
    return FIGURES[name]()


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for name in FIGURES:
        render(name).save(f'{OUT}/{name}.png', optimize=True)
        print('wrote', name)
