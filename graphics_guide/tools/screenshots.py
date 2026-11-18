"""Render the book's screenshots: run each example headless in PyBoy and save the screen as a PNG
(3x, nearest-neighbour) in book_src/img/.  The book embeds these files.

    .venv/bin/python tools/screenshots.py          (rewrites book_src/img/*.png)
"""
import os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, f'{ROOT}/tests')
import harness
from PIL import Image

OUT = f'{ROOT}/book_src/img'
SCALE = 3
BOOT = 120          # frames the emulator's boot ROM takes before the program is running

# name: program, frames to run, options
SHOTS = {
    'tiles_demo':     dict(prog='tiles_demo', frames=30),
    'palette_demo':   dict(prog='palette_demo', frames=5),
    'cgb_demo':       dict(prog='cgb_demo', frames=30, cgb=True),
    'pixel_demo':     dict(prog='pixel_demo', frames=30),
    'line_demo':      dict(prog='line_demo', frames=30),
    'shapes_demo':    dict(prog='shapes_demo', frames=30),
    'flood_demo':     dict(prog='flood_demo', frames=30),
    'invader':        dict(prog='invader', frames=100),
    'flicker_demo':   dict(prog='flicker_demo', frames=30),
    'scroll_demo':    dict(prog='scroll_demo', frames=150),
    'scroll2d_demo':  dict(prog='scroll2d_demo', frames=100),
    'parallax_demo':  dict(prog='parallax_demo', frames=90),
    'text_demo':      dict(prog='text_demo', frames=400),
    'anim_demo':      dict(prog='anim_demo', frames=30),
    'anim_profile':   dict(prog='anim_demo', frames=30, defines=('PROFILE=1',)),
    'walker_demo':    dict(prog='walker_demo', frames=30, press=('right', 25)),
}


def render(name):
    """The screenshot for `name` as a PIL image."""
    s = SHOTS[name]
    m = harness.Machine(s['prog'], frames=s['frames'] + BOOT, cgb=s.get('cgb', False), defines=s.get('defines', ()))
    try:
        if 'press' in s:
            button, n = s['press']
            m.pb.button_press(button)
            m.run(n)
            m.pb.button_release(button)
            m.run(2)
        img = Image.fromarray(m.pb.screen.ndarray[:, :, :3].copy())
    finally:
        m.stop()
    return img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for name in SHOTS:
        render(name).save(f'{OUT}/{name}.png', optimize=True)
        print('wrote', name)
