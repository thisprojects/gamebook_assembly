# Tests

The test suite assembles every program in `examples/` with RGBDS (any warning is a failure), runs it
headless on an emulated Game Boy ([PyBoy](https://github.com/Baekalfen/PyBoy)) and checks video memory,
work RAM, OAM and the rendered screen against independent Python models. It also checks the book itself:
the HTML is up to date, every listing marker points at a real file, links resolve, colours have enough contrast.

    python3 -m venv .venv
    .venv/bin/pip install -r tests/requirements.txt
    python3 tests/build_book.py                 # rebuild gameboy_graphics.html from book_src/
    .venv/bin/python tests/test_lib.py          # run everything
    .venv/bin/python tests/test_lib.py line_demo flood_demo   # run some

RGBDS is taken from `tools/rgbds/` if present, otherwise from your PATH.
Not covered: exact cycle counts (the speed test checks ordering, not absolute numbers), and real hardware.
