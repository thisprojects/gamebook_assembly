# Pixels, Tiles & Sprites: Game Boy Graphics in Assembly

A book (`gameboy_graphics.html`) about Game Boy graphics, with every listing assembled and tested.

- `book_src/`  the HTML parts; `python3 tests/build_book.py` assembles them into the book
- `lib/`       the routines (`gfx`, `canvas`, `tilemap`, `oam`, `scroll`, `text`, `vblank`, `joypad`, `cgb`, `fast`)
- `examples/`  one runnable program per topic, plus a Makefile (`make`, `make run-invader`)
- `tests/`     the test suite (see `tests/README.md`)
- `tools/rgbds/` prebuilt RGBDS binaries
- `tools/screenshots.py` renders the book's screenshots (`book_src/img/`) from the examples; rerun it after changing a demo
