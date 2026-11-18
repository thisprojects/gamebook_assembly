# Game Boy Assembly Books

Three books on Game Boy assembly, each with every listing assembled and tested.

- **Game Boy Assembly** (`gameboy_book.html`): sources in `gameboy_book_src/`, routines in `gameboy_lib/`, programs in `gameboy_examples/`, tests in `gameboy_tests/`.
- **Pixels, Tiles & Sprites: Game Boy Graphics in Assembly** (`graphics_guide/gameboy_graphics.html`): self-contained in `graphics_guide/` (`book_src/`, `lib/`, `examples/`, `tests/`). Rebuild with `python3 graphics_guide/tests/build_book.py`.

- **Beeps, Waves & Noise: Game Boy Sound in Assembly** (`sound_guide/gameboy_sound.html`): self-contained in `sound_guide/` (`book_src/`, `lib/`, `examples/`, `tests/`). Rebuild with `python3 sound_guide/tests/build_book.py`.

`tools/rgbds/` holds the prebuilt RGBDS binaries shared by all three (`graphics_guide/tools/rgbds` and `sound_guide/tools/rgbds` link to it).
