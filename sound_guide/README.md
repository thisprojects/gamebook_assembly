# Beeps, Waves & Noise: Game Boy Sound in Assembly

A book (`gameboy_sound.html`) about Game Boy sound, with every listing assembled and tested.

- `book_src/`  the HTML parts; `python3 tests/build_book.py` assembles them into the book
- `lib/`       the routines (`sound`, `frame`, `music`, `screen`, `joypad`, plus `notes.inc` and the text helpers)
- `examples/`  one runnable program per chapter, plus a Makefile (`make`, `make run-beep_demo`)
- `tests/`     the test suite (see `tests/README.md`)
- `tools/rgbds/` prebuilt RGBDS binaries
- `tools/figures.py` draws the book's figures (`book_src/img/`) from the sound the examples make; rerun it after changing a demo
