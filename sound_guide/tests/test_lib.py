"""Tests for lib/*.asm and examples/*.asm: assemble every program with RGBDS, run it headless on an
emulated Game Boy (PyBoy) with its sound switched on, and check both the sound registers and the
audio that comes out against independent Python models.  See tests/README.md.
Run:  .venv/bin/python tests/test_lib.py [test names]"""
import os, re, sys, traceback
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from harness import *
import build_book

BOOK = f'{ROOT}/gameboy_sound.html'
BOOT = 55           # frames the emulated boot ROM takes (its own start-up chime ends before this)
SPF = 70224 / 4194304 * SAMPLE_RATE      # audio samples in one frame (about 803)
TESTS = []


def test(f):
    TESTS.append(f)
    return f


# ---------------------------------------------------------------- helpers
def play(name, frames, events=(), **kw):
    """Run a program and record its sound from frame BOOT on.  `events` is a list of
    (frame, action) where action is ('press', button), ('release', button) or ('poke', addr, value).
    Returns (machine, audio, start) where audio[start + k * SPF] is the start of frame k of the run."""
    m = Machine(name, 0, record_from=BOOT, **kw)
    m.run(BOOT)
    pending = sorted(events, key=lambda e: e[0])
    for f in range(BOOT, frames):
        while pending and pending[0][0] == f:
            _, act, *args = pending.pop(0)
            if act == 'press':
                m.pb.button_press(args[0])
            elif act == 'release':
                m.pb.button_release(args[0])
            elif act == 'poke':
                m.pb.memory[args[0]] = args[1]
        m.run(1)
    return m, m.audio()


def frame_slice(audio, f0, f1):
    """The audio of frames f0..f1 of the run (frame numbers as in `play`)."""
    return audio[int((f0 - BOOT) * SPF):int((f1 - BOOT) * SPF)]


def first_sound(audio, level=0.001):
    """Sample index of the first non-silent sample."""
    nz = np.nonzero(np.abs(audio) > level)[0]
    assert len(nz), 'no sound at all'
    return int(nz[0])


def freq_square(seg):
    """Frequency of a square wave that is 0 or positive: count the 0 -> positive edges."""
    on = seg > 0.0005
    edges = np.nonzero(~on[:-1] & on[1:])[0]
    assert len(edges) >= 3, 'too few cycles to measure'
    return (len(edges) - 1) * SAMPLE_RATE / (edges[-1] - edges[0])


def duty(seg):
    """Fraction of the time a square wave is high."""
    on = seg > 0.0005
    edges = np.nonzero(~on[:-1] & on[1:])[0]
    whole = on[edges[0]:edges[-1]]
    return float(whole.mean())


def spectrum(seg):
    seg = seg - seg.mean()
    sp = np.abs(np.fft.rfft(seg * np.hanning(len(seg))))
    return sp, np.fft.rfftfreq(len(seg), 1 / SAMPLE_RATE)


def peak_freq(seg):
    sp, fr = spectrum(seg)
    return float(fr[sp.argmax()])


def harmonic(seg, f0, k):
    """Strength of the k-th harmonic of f0 relative to the fundamental."""
    sp, fr = spectrum(seg)
    near = lambda f: sp[(fr > f * 0.97) & (fr < f * 1.03)].max()
    return float(near(f0 * k) / near(f0))


def centroid(seg):
    sp, fr = spectrum(seg)
    return float((sp * fr).sum() / sp.sum())


def pitch_value(note):
    """The 11-bit pitch value for a note number, by the formula in Chapter 2."""
    hz = 440 * 2 ** ((note - 33) / 12)
    return round(2048 - 131072 / hz)


def square_hz(value):
    return 131072 / (2048 - value)


def read_table(name):
    """Values of the first `DW` table in lib/<name>."""
    text = open(f'{LIB}/{name}').read()
    return [int(v, 16) for line in re.findall(r'^\s*DW (.*?)(?:;|$)', text, re.M) for v in re.findall(r'\$([0-9A-F]+)', line)]


def screen_text(m, col, row, n):
    """n characters of the background map from (col, row), as a string."""
    return ''.join(chr(m[0x9800 + row * 32 + col + i]) for i in range(n))


def note_starts(audio, pattern, frame0, seg_frames=8):
    """For a stream of (duration) values starting at frame0 of the run, the audio of the first
    `seg_frames` of each event, skipping the first frame in case the note starts late."""
    out, t = [], frame0
    for d in pattern:
        out.append(frame_slice(audio, t + 1, t + 1 + min(seg_frames, d - 1)))
        t += d
    return out


# ---------------------------------------------------------------- the library
@test
def all_examples_assemble():
    names = sorted(f[:-4] for f in os.listdir(EXAMPLES) if f.endswith('.asm'))
    assert len(names) >= 11, names
    for n in names:
        build(n)


@test
def note_table_is_in_tune():
    """NoteTable holds the 11-bit pitch for every note C2..B7, equal temperament, A4 = 440 Hz."""
    table = read_table('sound.asm')
    assert len(table) == 72, len(table)
    assert table == [pitch_value(n) for n in range(72)], 'table differs from 2048 - 131072 / f'
    assert table[33] == 0x6D6 and abs(square_hz(table[33]) - 440) < 1
    for n in range(72):                      # every note within a fifth of a semitone of true (much closer in the low octaves)
        true = 440 * 2 ** ((n - 33) / 12)
        cents = 1200 * np.log2(square_hz(table[n]) / true)
        assert abs(cents) < (6 if n < 48 else 11.5 if n < 60 else 20.5), (n, cents)    # the top octaves are coarse: Chapter 2 says so


@test
def note_names_match_note_constants():
    inc = open(f'{LIB}/notes.inc').read()
    consts = dict((k, int(v)) for k, v in re.findall(r'DEF (\w+) EQU (\d+)', inc))
    assert consts['C2'] == 0 and consts['A4'] == 33 and consts['C5'] == 36 and consts['B7'] == 71
    assert consts['Cs4'] == 25 and consts['As3'] == 22


# ---------------------------------------------------------------- chapter 1
@test
def beep_demo():
    m, a = play('beep_demo', 175)
    assert m[0xFF26] & 0x80, 'master sound switch is on'
    assert m[0xFF24] == 0x77 and m[0xFF25] == 0xFF
    assert m[0xFF12] == 0xF3 and m[0xFF11] & 0xC0 == 0x80
    assert screen_text(m, 2, 2, 18) == 'Channel 1: 2048 Hz'
    s0 = first_sound(a)
    seg = a[s0 + 2000:s0 + 2000 + 24000]
    assert abs(freq_square(seg) - 131072 / (2048 - 0x7C0)) < 20, freq_square(seg)    # 2048 Hz
    assert abs(duty(seg) - 0.5) < 0.03, duty(seg)
    early, late = np.abs(a[s0:s0 + 4000]).max(), np.abs(a[s0 + 40000:s0 + 44000]).max()
    assert early > 0.1 and late < early * 0.6, (early, late)             # the envelope fades it
    assert np.abs(a[-4000:]).max() == 0, 'silent again after about a second'
    m.stop()


# ---------------------------------------------------------------- chapter 2
@test
def scale_demo():
    m, a = play('scale_demo', 280)
    s0 = first_sound(a)
    f0 = BOOT + s0 / SPF
    scale = [24, 26, 28, 29, 31, 33, 35, 36]
    names = ['C-4', 'D-4', 'E-4', 'F-4', 'G-4', 'A-4', 'B-4', 'C-5']
    for k, note in enumerate(scale):
        seg = frame_slice(a, f0 + 24 * k + 2, f0 + 24 * k + 12)
        got, want = freq_square(seg), 440 * 2 ** ((note - 33) / 12)
        assert abs(1200 * np.log2(got / want)) < 15, (k, got, want)
    m.stop()
    # the note names on the screen
    for k, name in enumerate(names):
        m2 = Machine('scale_demo', int(f0) + 12 + 24 * k)
        assert screen_text(m2, 2, 5, 3) == name, (k, screen_text(m2, 2, 5, 3))
        m2.stop()


# ---------------------------------------------------------------- chapter 3
@test
def duty_demo():
    m, a = play('duty_demo', 260)
    f0 = BOOT + first_sound(a) / SPF
    for k, want in enumerate((0.125, 0.25, 0.5, 0.75)):
        seg = frame_slice(a, f0 + 45 * k + 3, f0 + 45 * k + 40)
        assert abs(freq_square(seg) - 440) < 3, (k, freq_square(seg))
        assert abs(duty(seg) - want) < 0.02, (k, duty(seg))
    m.stop()
    for k, label in enumerate(('12.5%', '25%  ', '50%  ', '75%  ')):
        m2 = Machine('duty_demo', BOOT + 20 + 45 * k)
        assert screen_text(m2, 2, 5, 5) == label, (k, screen_text(m2, 2, 5, 5))
        assert m2[0xFF11] & 0xC0 == (0x00, 0x40, 0x80, 0xC0)[k]
        m2.stop()


# ---------------------------------------------------------------- chapter 4
@test
def envelope_demo():
    m, a = play('envelope_demo', 560)
    f0 = BOOT + first_sound(a) / SPF
    level = lambda f: float(np.abs(frame_slice(a, f, f + 3)).max())
    step = 1 / 8 / 15                                   # one volume step: 1/15 of full scale 0.117 = 0.0078
    full = level(f0 + 1)
    assert abs(full - 0.117) < 0.01, full
    # pluck: gone within a quarter of a second (1/64 s * 15 steps); fade: still sounding after 0.8 s
    assert level(f0 + 18) < 0.01, level(f0 + 18)
    assert level(f0 + 120 + 48) > 0.03 and level(f0 + 120 + 100) < 0.02
    # swell: starts silent and grows, then holds
    s0 = f0 + 240
    assert level(s0 + 1) < 0.02 and level(s0 + 20) > level(s0 + 5) + 0.02, (level(s0 + 1), level(s0 + 20))
    assert level(s0 + 60) > 0.1 and abs(level(s0 + 60) - level(s0 + 100)) < 0.005
    # steady: volume 12 and never changes
    t0 = f0 + 360
    assert abs(level(t0 + 2) - level(t0 + 100)) < 0.005 and abs(level(t0 + 2) - 12 / 15 * 0.117) < 0.01
    m.stop()


# ---------------------------------------------------------------- chapter 5
@test
def sfx_demo():
    m, a = play('sfx_demo', 140, events=[(70, 'press', 'a'), (72, 'release', 'a'),
                                          (100, 'press', 'b'), (102, 'release', 'b'),
                                          (125, 'press', 'start'), (127, 'release', 'start')])
    m.stop()
    # coin: B5 then E6, both stopped by the length counter
    f = 70
    first = frame_slice(a, f + 2, f + 6)
    assert abs(freq_square(first) - 440 * 2 ** (14 / 12)) < 8, freq_square(first)      # B5 = 987.8 Hz
    second = frame_slice(a, f + 12, f + 20)
    assert abs(freq_square(second) - 440 * 2 ** (19 / 12)) < 10, freq_square(second)  # E6 = 1318.5 Hz
    sound = np.abs(frame_slice(a, 70, 100)) > 0.001
    idx = np.nonzero(sound)[0]
    assert (idx[-1] - idx[0]) / SPF < 6 + 11 + 2, 'the coin lasts about 17 frames and then stops by itself'
    assert not (np.abs(frame_slice(a, 92, 99)) > 0.001).any(), 'silent after the coin'
    # blip: C6 for about 31 ms (2 frames)
    blip = frame_slice(a, 100, 125)
    idx = np.nonzero(np.abs(blip) > 0.001)[0]
    assert 1.2 < (idx[-1] - idx[0]) / SPF < 3.5, (idx[-1] - idx[0]) / SPF
    assert abs(freq_square(blip[idx[0]:idx[-1]]) - 440 * 2 ** (15 / 12)) < 30
    assert abs(duty(blip[idx[0]:idx[-1]]) - 0.25) < 0.04, duty(blip[idx[0]:idx[-1]])
    # bonk: noise, about 47 ms (3 frames), no steady pitch
    bonk = frame_slice(a, 125, 140)
    idx = np.nonzero(np.abs(bonk) > 0.001)[0]
    assert 1.2 < (idx[-1] - idx[0]) / SPF < 5, (idx[-1] - idx[0]) / SPF


# ---------------------------------------------------------------- chapter 6
@test
def sweep_demo():
    m, a = play('sweep_demo', 400)
    f0 = BOOT + first_sound(a) / SPF
    hz = lambda f, n=3: peak_freq(frame_slice(a, f, f + n))
    # jump: rises, then runs off the top of the range and the channel stops itself
    j = [hz(f0 + k, 4) for k in (1, 5, 9)]
    assert j[0] < j[1] < j[2], j
    assert (np.abs(frame_slice(a, f0 + 30, f0 + 60)) < 0.001).all(), 'a rising sweep that passes 2047 silences the channel'
    # laser: falls
    l0 = f0 + 90
    l = [hz(l0 + k, 4) for k in (1, 5, 9, 15)]
    assert l[0] > l[1] > l[2] > l[3], l
    # slide: slowly falls from 2048 Hz
    s0 = f0 + 180
    s = [hz(s0 + k, 6) for k in (0, 20, 60, 110)]
    assert s[0] > 1500 and all(x > y for x, y in zip(s, s[1:])), s
    m.stop()


# ---------------------------------------------------------------- chapter 7
@test
def wave_demo():
    m, a = play('wave_demo', 380)
    f0 = BOOT + first_sound(a) / SPF
    shapes = {}
    for k, name in enumerate(('sine', 'triangle', 'saw', 'pulse')):
        seg = frame_slice(a, f0 + 75 * k + 10, f0 + 75 * k + 60)
        assert abs(peak_freq(seg) - 220) < 4, (name, peak_freq(seg))          # A3 for all four
        shapes[name] = [harmonic(seg, 220, n) for n in (2, 3, 4, 5)]
    sine, tri, saw, pulse = (shapes[n] for n in ('sine', 'triangle', 'saw', 'pulse'))
    assert max(sine) < 0.08, sine                                          # nearly pure
    assert tri[0] < 0.05 and 0.07 < tri[1] < 0.15, tri                    # odd harmonics only, falling as 1/n^2
    assert 0.4 < saw[0] < 0.6 and 0.25 < saw[1] < 0.42, saw                # all harmonics, falling as 1/n
    assert pulse[2] < 0.1 and pulse[0] > 0.5, pulse                       # a 1/4 pulse has no 4th harmonic
    assert m[0xFF1C] & 0x60 == 0x20 and m[0xFF1A] & 0x80
    m.stop()


@test
def wave_tables_are_the_shapes_the_book_names():
    """The four 16-byte wave tables in wave_demo are 32 four-bit samples of a sine, triangle, sawtooth and 1/4 pulse
    (wave RAM itself cannot be read back while a wave plays, so the tables in the ROM are checked)."""
    m = Machine('wave_demo', 1)
    rom = open(m.rom, 'rb').read()
    base = m.sym['Waves']
    unpack = lambda blob: [s for b in blob for s in (b >> 4, b & 15)]
    got = [unpack(rom[base + 16 * k:base + 16 * k + 16]) for k in range(4)]
    sine = [round(7.5 + 7.5 * np.sin(2 * np.pi * (i + 0.5) / 32)) for i in range(32)]
    tri = [i if i < 16 else 31 - i for i in range(32)]
    saw = [i // 2 for i in range(32)]
    pulse = [15] * 8 + [0] * 24
    assert got == [sine, tri, saw, pulse], got
    assert all(0 <= s <= 15 for w in got for s in w)
    m.stop()


# ---------------------------------------------------------------- chapter 8
@test
def noise_demo():
    m, a = play('noise_demo', 380)
    f0 = BOOT + first_sound(a) / SPF
    cents = []
    for k in range(5):
        seg = frame_slice(a, f0 + 60 * k + 1, f0 + 60 * k + 9)
        cents.append(centroid(seg))
    kick, snare, hat, boom, buzz = cents
    assert kick < snare < hat, cents                    # higher setting = higher noise
    assert boom < snare, cents
    assert hat > 8000, hat
    # the 15-bit noise never repeats; the 7-bit "buzz" repeats every 127 clock ticks (shift 2, divisor 3: 21845 Hz)
    lag = round(127 / (262144 / (3 * 4)) * SAMPLE_RATE)

    def repeat(seg):
        seg = seg - seg.mean()
        return float((seg[:-lag] * seg[lag:]).sum() / (seg * seg).sum())
    assert repeat(frame_slice(a, f0 + 240 + 1, f0 + 240 + 8)) > 0.5
    assert abs(repeat(frame_slice(a, f0 + 60 + 1, f0 + 60 + 8))) < 0.3, repeat(frame_slice(a, f0 + 60 + 1, f0 + 60 + 8))
    # decays: the hi-hat is much shorter than the explosion
    def length(k, n=60):
        s = frame_slice(a, f0 + 60 * k, f0 + 60 * k + n)
        idx = np.nonzero(np.abs(s) > 0.004)[0]
        return (idx[-1] - idx[0]) / SPF
    assert length(2) < 10 and length(3) > 25, (length(2), length(3))
    m.stop()


# ---------------------------------------------------------------- chapter 9
@test
def timing_demo():
    m, a = play('timing_demo', 420)
    s = np.abs(a) > 0.001
    idx = np.nonzero(s)[0]
    onsets = [idx[0]] + [idx[i] for i in range(1, len(idx)) if idx[i] - idx[i - 1] > 2000]
    assert len(onsets) >= 11, len(onsets)
    gaps = np.diff(onsets) / SPF
    assert (abs(gaps - 30) < 0.5).all(), gaps                       # 30 frames a beat
    notes = [freq_square(a[o + 100:o + 1200]) for o in onsets[:8]]
    assert all(abs(n - (880 if k % 4 == 0 else 440)) < 10 for k, n in enumerate(notes)), notes
    # about 120 beats a minute: 60 s of frames at the real frame rate
    assert abs(60 / (30 * 70224 / 4194304) - 120) < 1
    m.stop()
    m2 = Machine('timing_demo', BOOT + 30 * 3 + 20)
    assert screen_text(m2, 8, 5, 1) in '234'
    m2.stop()


@test
def frame_counter_counts_frames():
    m = Machine('timing_demo', 90)
    t0 = m[m.sym['wTicks']]
    m.run(200)
    assert (m[m.sym['wTicks']] - t0) % 256 == 200 % 256
    m.stop()


# ---------------------------------------------------------------- chapter 10
# the song, as the book prints it: (note, frames) per channel
A2, E3, F2, C3, G3, G2, D3 = 9, 16, 5, 12, 19, 7, 14
A4, C5, E5, E4, F4, C4, G5, G4, B4, D5, D4 = 33, 36, 40, 28, 29, 24, 43, 31, 35, 38, 26
LEAD = [(A4, 12), (C5, 12), (E5, 24), (C5, 12), (A4, 12), (E4, 24),
        (F4, 12), (A4, 12), (C5, 24), (A4, 12), (F4, 12), (C4, 24),
        (C5, 12), (E5, 12), (G5, 24), (E5, 12), (C5, 12), (G4, 24),
        (G4, 12), (B4, 12), (D5, 24), (B4, 12), (G4, 12), (D4, 24)]
BASS = [(A2, 24), (A2, 24), (E3, 24), (A2, 24), (F2, 24), (F2, 24), (C3, 24), (F2, 24),
        (C3, 24), (C3, 24), (G3, 24), (C3, 24), (G2, 24), (G2, 24), (D3, 24), (G2, 24)]


def isolate(channel):
    return {1: 0x11, 2: 0x22, 3: 0x44, 4: 0x88}[channel]


def song_run(channel, frames, presses=()):
    """Run music_demo with only `channel` reaching the speakers.  The moment the song starts (wMusicOn
    becomes 1) NR51 is changed, so the very first sound is the first note of that channel.
    `presses` are (frames after the song began, button).  Returns (machine, audio, f0), f0 = the frame
    the channel's first note begins, so that frame f0 + n is n frames into the song."""
    m = Machine('music_demo', 0, record_from=BOOT)
    m.run(BOOT)
    while m[m.sym['wMusicOn']] != 1:
        m.run(1)
    m.pb.memory[0xFF25] = isolate(channel)
    t0 = m.frame
    for f in range(t0, t0 + frames):
        for p in presses:
            if f - t0 == p[0]:
                m.pb.button_press(p[1])
            if f - t0 == p[0] + 2:
                m.pb.button_release(p[1])
        m.run(1)
    a = m.audio()
    f0 = t0 + first_sound(a[int((t0 - BOOT) * SPF):]) / SPF
    return m, a, round(f0)


@test
def music_demo_lead():
    """Channel 1 plays the lead melody: right pitches at the right times."""
    m, a, f0 = song_run(1, 300)
    t = f0
    for note, dur in LEAD[:12]:
        got = freq_square(frame_slice(a, t + 2, t + dur - 1))
        want = square_hz(pitch_value(note))
        assert abs(1200 * np.log2(got / want)) < 20, (t, note, got, want)
        t += dur
    m.stop()


@test
def music_demo_bass_arp_drums():
    """Channel 2 arpeggiates A minor, channel 3 plays the bass, channel 4 the drums."""
    # channel 2: A3 C4 E4 C4, six frames each
    m, a, f0 = song_run(2, 120)
    for k, note in enumerate((21, 24, 28, 24, 21, 24, 28, 24)):
        got = freq_square(frame_slice(a, f0 + 6 * k + 1, f0 + 6 * k + 5))
        assert abs(1200 * np.log2(got / square_hz(pitch_value(note)))) < 40, (k, note, got)
    m.stop()
    # channel 3: bass, an octave lower than the square notes would be: A2 A2 E3 A2
    m, a, f0 = song_run(3, 200)
    for k, (note, dur) in enumerate(BASS[:6]):
        seg = frame_slice(a, f0 + 24 * k + 3, f0 + 24 * k + 20)
        want = 440 * 2 ** ((note - 33) / 12)
        assert abs(1200 * np.log2(peak_freq(seg) / want)) < 60, (k, note, peak_freq(seg), want)
    m.stop()
    # channel 4: one drum every 12 frames, alternating low (kick, snare) with high (hat)
    m, a, f0 = song_run(4, 120)
    c = [centroid(frame_slice(a, f0 + 12 * k + 1, f0 + 12 * k + 6)) for k in range(8)]
    hats = [c[1], c[3], c[5], c[7]]
    others = [c[0], c[2], c[4], c[6]]
    assert min(hats) > 1.4 * max(others), c
    assert c[0] < c[2] < min(hats), c                  # the kick is lower than the snare
    m.stop()


@test
def music_loops_and_streams_stay_in_step():
    """After exactly one pass (384 frames) every channel is back at its first event, together."""
    m = Machine('music_demo', 0)
    m.run(BOOT + 30)
    ptr = lambda c: m.word(m.sym['wChanPtr'] + 2 * c)
    start = [m.word(m.sym['wChanStart'] + 2 * c) for c in range(4)]
    assert start == [m.sym['LeadStream'], m.sym['ArpStream'], m.sym['BassStream'], m.sym['DrumStream']], start
    seen = []
    for f in range(BOOT + 30, BOOT + 30 + 1200):
        m.run(1)
        if ptr(0) == start[0] + 2:                  # the lead has just read its first event
            seen.append(f)
    # the lead is at its second byte-pair once per pass, about every 384 frames
    firsts = [f for i, f in enumerate(seen) if i == 0 or f - seen[i - 1] > 5]
    assert len(firsts) >= 3 and all(abs((b - a) - 384) <= 1 for a, b in zip(firsts, firsts[1:])), firsts
    m.stop()


@test
def music_engine_rests_unused_channels_and_loops():
    """A rest silences its channel, a channel with no stream stays silent, and SONG_LOOP starts the
    stream again, using a tiny song written for the test (tests/music_edge.asm)."""
    m = Machine('music_edge', 0, src_dir=os.path.dirname(os.path.abspath(__file__)), record_from=BOOT)
    m.run(BOOT)
    while m[m.sym['wMusicOn']] != 1:
        m.run(1)
    t0 = m.frame
    m.run(300)
    a = m.audio()
    f0 = t0 + first_sound(a[int((t0 - BOOT) * SPF):]) / SPF
    loud = lambda f0_, f1_: float(np.abs(frame_slice(a, f0_, f1_)).max())
    for lap in range(3):                           # the stream is A4 (24 frames), rest (24), A4 (24): 72 frames a lap
        s = round(f0) + 72 * lap
        assert loud(s + 2, s + 22) > 0.05, (lap, 'first note')
        assert loud(s + 28, s + 46) == 0, (lap, 'rest')
        assert loud(s + 52, s + 70) > 0.05, (lap, 'second note')
    # the steady note really was steady (no envelope), so only the rest could have silenced it
    assert abs(loud(round(f0) + 2, round(f0) + 22) - loud(round(f0) + 52, round(f0) + 70)) < 0.01
    m.stop()
    # the three unused channels make no sound: listen with channel 1 left out
    m = Machine('music_edge', 0, src_dir=os.path.dirname(os.path.abspath(__file__)), record_from=BOOT)
    m.run(BOOT)
    while m[m.sym['wMusicOn']] != 1:
        m.run(1)
    m.pb.memory[0xFF25] = 0xEE
    t0 = m.frame
    m.run(200)
    assert np.abs(m.audio()[int((t0 - BOOT) * SPF):]).max() == 0, 'unused channels must be silent'
    m.stop()


@test
def sfx_takes_channel_one_and_gives_it_back():
    """Pressing A fires an effect on channel 1 for 20 frames: the music skips channel 1 meanwhile, and
    afterwards the sweep and duty the effect set are put back before the next note."""
    m, a, f0 = song_run(1, 300, presses=[(100, 'a')])
    press = f0 + 100
    # during the effect: a rising pitch (the lead note that would have played is not heard)
    p = [peak_freq(frame_slice(a, press + 2 + k, press + 6 + k)) for k in (0, 3, 6)]
    assert p[0] < p[1] < p[2], p
    # the music resumes with its own notes and its own duty (25%), and no sweep left over
    t = f0
    for note, dur in LEAD:                      # the first lead note that starts after the effect has ended
        if t > press + 22:
            seg = frame_slice(a, t + 2, t + dur - 1)
            assert abs(1200 * np.log2(freq_square(seg) / square_hz(pitch_value(note)))) < 20
            assert abs(duty(seg) - 0.25) < 0.03, duty(seg)
            break
        t += dur
    assert m[0xFF10] & 0x77 == 0
    m.stop()
    # and the other three channels did not notice: channel 3's bass line is unchanged across the press
    m, a, f0 = song_run(3, 200, presses=[(100, 'a')])
    for k in (3, 4):
        seg = frame_slice(a, f0 + 24 * k + 3, f0 + 24 * k + 20)
        want = 440 * 2 ** ((BASS[k][0] - 33) / 12)
        assert abs(1200 * np.log2(peak_freq(seg) / want)) < 60, (k, peak_freq(seg), want)
    m.stop()


# ---------------------------------------------------------------- chapter 11
@test
def instrument_demo():
    buttons = ['a', 'b', 'select', 'start', 'right', 'left', 'up', 'down']
    notes = [43, 45, 47, 48, 36, 38, 40, 41]
    events = []
    for k, b in enumerate(buttons):
        events += [(70 + 40 * k, 'press', b), (73 + 40 * k, 'release', b)]
    m, a = play('instrument_demo', 70 + 40 * 8, events=events)
    for k, note in enumerate(notes):
        seg = frame_slice(a, 70 + 40 * k + 3, 70 + 40 * k + 12)
        got, want = freq_square(seg), 440 * 2 ** ((note - 33) / 12)
        assert abs(1200 * np.log2(got / want)) < 15, (buttons[k], got, want)
    m.stop()
    names = ['G-5', 'A-5', 'B-5', 'C-6', 'C-5', 'D-5', 'E-5', 'F-5']
    for k in (0, 3, 7):
        m2, _ = play('instrument_demo', 70 + 40 * k + 10, events=events[:2 * (k + 1)])
        assert screen_text(m2, 10, 7, 3) == names[k], (k, screen_text(m2, 10, 7, 3))
        m2.stop()


@test
def holding_a_button_plays_once():
    """read_joypad's 'newly pressed' byte means a held button triggers its note only once."""
    m, a = play('instrument_demo', 200, events=[(70, 'press', 'right')])
    nz = np.abs(a) > 0.001
    idx = np.nonzero(nz)[0]
    onsets = [idx[0]] + [idx[i] for i in range(1, len(idx)) if idx[i] - idx[i - 1] > 300]
    assert len(onsets) == 1, len(onsets)
    m.stop()


@test
def book_note_table_matches_note_table():
    """Appendix C prints the pitch values: they must be the ones in NoteTable."""
    html_text = open(f'{ROOT}/book_src/50-appendix.html').read()
    table = read_table('sound.asm')
    shown = [int(v, 16) for v in re.findall(r'<code>\$([0-9A-F]{3})</code>', html_text.split('id="appendix-c-notes"')[1])]
    assert shown[:72] == table, 'Appendix C differs from NoteTable'


@test
def print_note_names():
    """print_note turns a note number into a name like C-4 or F#5, for every note."""
    names = ['C-', 'C#', 'D-', 'D#', 'E-', 'F-', 'F#', 'G-', 'G#', 'A-', 'A#', 'B-']
    src = open(f'{LIB}/screen.asm').read()
    table = re.search(r'NoteNames:\s*DB (.*)', src).group(1)
    assert re.findall(r'"(..)"', table) == names


# ---------------------------------------------------------------- the book
@test
def book_is_up_to_date():
    assert open(BOOK).read() == build_book.build(), 'run: python3 tests/build_book.py'


@test
def book_standalone_and_links_work():
    html_text = open(BOOK).read()
    low = re.sub(r'data:[\w/+.-]+;base64,[A-Za-z0-9+/=]+', '', html_text).lower()   # (not the embedded images)
    for word in ('spectrum', 'zx ', 'z80', 'norbert', 'norbsoft'):
        assert word not in low, f'the book must stand alone, but mentions {word!r}'
    ids = set(re.findall(r'id="([^"]+)"', html_text))
    assert len(ids) == len(re.findall(r'id="([^"]+)"', html_text)), 'duplicate ids'
    missing = [h for h in re.findall(r'href="#([^"]+)"', html_text) if h not in ids]
    assert not missing, missing
    for n in range(1, 12):
        assert re.search(rf'<h1 id="[^"]+">{n}\. ', html_text), f'chapter {n} missing'
    assert 'Appendix A' in html_text and 'Appendix B' in html_text


@test
def book_figures_match_the_programs():
    """Every PNG in book_src/img is what its program sounds like now, and every one is used in the book."""
    sys.path.insert(0, os.path.join(ROOT, 'tools'))
    import figures
    from PIL import Image, ImageChops
    used = set(re.findall(r'\[\[(?:shot|fig) (\w+) \|', build_book.source_text()))
    assert used == set(figures.FIGURES), used ^ set(figures.FIGURES)
    for name in sorted(used):
        old = Image.open(f'{figures.OUT}/{name}.png').convert('RGB')
        assert ImageChops.difference(old, figures.render(name)).getbbox() is None, \
            f'{name}.png is out of date: run tools/figures.py'


@test
def book_listings_are_the_tested_files():
    """Every [[file x]] / [[part x | a | b]] marker in the sources must point at a real file, and every example is shown."""
    src = build_book.source_text()
    shown = set(re.findall(r'\[\[file ([\w.]+)\]\]', src))
    for name in shown:
        build_book.read_source(name)
    for f in os.listdir(EXAMPLES):
        if f.endswith('.asm'):
            assert f in shown, f'{f} is not listed in the book'
    n_files = len(re.findall(r'\[\[file ', src)) + len(re.findall(r'\[\[part ', src))
    assert n_files >= 20, n_files
    for name in re.findall(r'\[\[part ([\w.]+) \|', src):
        build_book.read_source(name)


def luminance(hexcolour):
    r, g, b = (int(hexcolour[i:i + 2], 16) / 255 for i in (1, 3, 5))
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


@test
def book_colours_are_readable():
    css = open(f'{ROOT}/book_src/00-head.html').read()
    var = dict(re.findall(r'--([\w-]+):\s*(#[0-9a-fA-F]{6})', css))
    pairs = [('text', 'bg'), ('text-dim', 'bg'), ('text', 'surface'), ('text-dim', 'surface'), ('link', 'bg'),
             ('link', 'surface'), ('heading', 'bg'), ('code-text', 'code-bg'), ('code-comment', 'code-bg'),
             ('code-keyword', 'code-bg'), ('code-label', 'code-bg'), ('code-string', 'code-bg'),
             ('code-number', 'code-bg'), ('code-directive', 'code-bg'), ('inline-code-text', 'inline-code-bg')]
    for fg, bg in pairs:
        a, b = sorted((luminance(var[fg]), luminance(var[bg])), reverse=True)
        ratio = (a + 0.05) / (b + 0.05)
        assert ratio >= 4.5, f'{fg} on {bg}: contrast {ratio:.2f}'


# ---------------------------------------------------------------- runner
if __name__ == '__main__':
    wanted = sys.argv[1:]
    todo = [t for t in TESTS if not wanted or t.__name__ in wanted]
    failed = 0
    for t in todo:
        try:
            t()
            print(f'ok    {t.__name__}')
        except Exception:
            failed += 1
            print(f'FAIL  {t.__name__}')
            traceback.print_exc(limit=3)
    print(f'\n{len(todo) - failed} passed, {failed} failed')
    sys.exit(1 if failed else 0)
