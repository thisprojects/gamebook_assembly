# Game Boy tests

Assembles every file in `gameboy_lib/` and `gameboy_examples/` with RGBDS, runs each program on an emulated
Game Boy (PyBoy, headless), and checks what appears on screen. It also runs the code blocks quoted in
`gameboy_book.html` and checks the book itself (structure against the Z80 book, links, colour contrast).

    python3 -m venv .venv && .venv/bin/pip install -r gameboy_tests/requirements.txt
    .venv/bin/python gameboy_tests/test_lib.py [test names]

RGBDS (`rgbasm`, `rgblink`, `rgbfix`) is taken from `tools/rgbds/` if present, otherwise from your PATH.
Install it with `brew install rgbds`, or unzip the `rgbds-macos.zip` / Linux build from
https://github.com/gbdev/rgbds/releases into `tools/rgbds/`.

## The book is generated

`gameboy_book.html` is built from `gameboy_book_src/*.html` by `python3 gameboy_tests/build_book.py`.
Whole programs in the book are pulled from `gameboy_lib/`, so the listings cannot drift from the tested code.
Edit the sources, rebuild, and run the tests (one test fails if the HTML is stale).
