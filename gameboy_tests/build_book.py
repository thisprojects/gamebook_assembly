"""Build gameboy_book.html from the parts in gameboy_book_src/.

The parts are ordinary HTML with three extra markers, so that every code listing in the book is
syntax-highlighted automatically and whole programs are pulled straight from gameboy_lib/ (the files
the test suite assembles and runs):

    [[asm]] ...plain assembly, not HTML-escaped... [[/asm]]   highlighted code block
    [[text]] ...plain text... [[/text]]                        un-highlighted block (screen output, shell commands)
    [[file first.asm]]                                         a whole file from gameboy_lib/, highlighted
    [[part debug_output.asm | debug_init: | ; --- Move the cursor]]   part of a file: from the first line starting with
                                                               START up to (not including) the first later line containing END

Usage:  python3 gameboy_tests/build_book.py          (writes gameboy_book.html)
"""
import glob, html, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = f'{ROOT}/gameboy_book_src'
LIB = f'{ROOT}/gameboy_lib'
OUT = f'{ROOT}/gameboy_book.html'

MNEMONICS = set('''LD LDH ADD ADC SUB SBC AND OR XOR CP INC DEC DAA CPL CCF SCF RLCA RLA RRCA RRA RLC RL RRC RR SLA SRA
SRL SWAP BIT RES SET JP JR CALL RET RETI RST PUSH POP NOP HALT STOP EI DI'''.split())
DIRECTIVES = set('''DB DW DS EQU DEF SECTION INCLUDE EXPORT PUSHS POPS IF ELSE ENDC MACRO ENDM REDEF EQUS RSRESET RSSET
RB RW INCBIN'''.split())

TOKEN = re.compile(r'''
    (?P<string>"[^"]*")
  | (?P<char>'[^']')
  | (?P<number>\$[0-9A-Fa-f]+|%[01]+|\b\d+\b)
  | (?P<word>[A-Za-z_][\w.]*:{0,2}|\.[A-Za-z_]\w*:{0,2})
''', re.X)


def esc(s):
    return html.escape(s, quote=False)


def split_comment(line):
    """Return (code, comment) - the comment starts at the first ';' that is not inside a string or char literal."""
    i, n = 0, len(line)
    while i < n:
        c = line[i]
        if c == '"':
            j = line.find('"', i + 1)
            i = n if j < 0 else j + 1
            continue
        if c == "'" and i + 2 < n and line[i + 2] == "'":
            i += 3
            continue
        if c == ';':
            return line[:i], line[i:]
        i += 1
    return line, ''


def highlight_line(line):
    code, comment = split_comment(line.rstrip())
    out, pos, seen_op = [], 0, False
    for m in TOKEN.finditer(code):
        out.append(esc(code[pos:m.start()]))
        text, kind = m.group(), m.lastgroup
        if kind in ('string', 'char'):
            out.append(f'<span class="string">{esc(text)}</span>')
        elif kind == 'number':
            out.append(f'<span class="number">{esc(text)}</span>')
        else:
            bare = text.rstrip(':')
            if text.endswith(':'):
                out.append(f'<span class="label">{esc(bare)}</span>{esc(text[len(bare):])}')
            elif not seen_op and bare.upper() in MNEMONICS:
                out.append(f'<span class="keyword">{esc(text)}</span>'); seen_op = True
            elif not seen_op and bare.upper() in DIRECTIVES:
                out.append(f'<span class="directive">{esc(text)}</span>'); seen_op = True
            elif not seen_op and m.start() == 0 and code[m.end():m.end() + 1] in (' ', '\t') and \
                    re.match(r'\s+(DB|DW|DS|EQU)\b', code[m.end():], re.I):
                out.append(f'<span class="label">{esc(text)}</span>')       # label without a colon, e.g. "msg_len EQU ..."
            else:
                out.append(esc(text))
        pos = m.end()
    out.append(esc(code[pos:]))
    if comment:
        out.append(f'<span class="comment">{esc(comment)}</span>')
    return ''.join(out)


def highlight(code):
    return '\n'.join(highlight_line(l) for l in code.strip('\n').split('\n'))


def expand(text):
    def asm(m):
        return f'<pre><code>{highlight(m.group(1))}</code></pre>'
    def plain(m):
        return f'<pre><code>{esc(m.group(1).strip(chr(10)))}</code></pre>'
    def file(m):
        return f'<pre><code>{highlight(open(f"{LIB}/{m.group(1)}").read())}</code></pre>'
    text = re.sub(r'\[\[asm\]\]\n?(.*?)\[\[/asm\]\]', asm, text, flags=re.S)
    text = re.sub(r'\[\[text\]\]\n?(.*?)\[\[/text\]\]', plain, text, flags=re.S)
    def part(m):
        name, start, end = (x.strip() for x in m.group(1).split('|'))
        lines = open(f'{LIB}/{name}').read().split('\n')
        i = next(k for k, l in enumerate(lines) if l.startswith(start))
        j = next(k for k in range(i + 1, len(lines)) if end in lines[k])
        return f'<pre><code>{highlight(chr(10).join(lines[i:j]).rstrip())}</code></pre>'
    text = re.sub(r'\[\[file ([\w.]+)\]\]', file, text)
    text = re.sub(r'\[\[part ([^\]]+)\]\]', part, text)
    return text


def source_text():
    """The raw text of all parts, in order (also used by the tests to check that quoted snippets are in the book)."""
    return ''.join(open(p).read() for p in sorted(glob.glob(f'{SRC}/*.html')))


def build():
    text = expand(source_text())
    leftover = re.findall(r'\[\[[^\]]*\]\]', text)
    assert not leftover, f'unprocessed markers: {leftover[:3]}'
    return text


if __name__ == '__main__':
    open(OUT, 'w').write(build())
    print(f'wrote {OUT}')
