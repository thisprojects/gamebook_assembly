# Tests

The test suite assembles every program in `examples/` with RGBDS (any warning is a failure), runs it
headless on an emulated Game Boy ([PyBoy](https://github.com/Baekalfen/PyBoy)) with sound switched on, and
checks the **sound itself**: the recorded audio is measured (pitch, duty cycle, loudness over time, length,
sweep direction, wave shape, noise brightness, beat spacing) and compared with independent Python models of
what the registers say it should be. The music engine is tested one channel at a time by routing a single
channel to the speakers (`rNR51`). It also checks the book itself: the HTML is up to date, every listing marker
points at a real file, links resolve, the figures match what the programs sound like now, colours have enough contrast.

    python3 -m venv .venv
    .venv/bin/pip install -r tests/requirements.txt
    python3 tests/build_book.py                 # rebuild gameboy_sound.html from book_src/
    .venv/bin/python tools/figures.py           # redraw the figures after changing a demo
    .venv/bin/python tests/test_lib.py          # run everything
    .venv/bin/python tests/test_lib.py beep_demo scale_demo   # run some

RGBDS is taken from `tools/rgbds/` if present, otherwise from your PATH.
`tests/music_edge.asm` is a small song used only by the tests (rests, an empty channel, looping).
Not covered: real hardware, real speakers, and whether a tune is pleasing.
