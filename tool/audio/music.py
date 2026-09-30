"""The music: one lullaby in four states, two ambiences and the true-ending
chord. Each function returns stereo (2, n); loops are exactly one cycle.

The lullaby is the game's voice. It starts friendly (`trust`), is caught
lying (`lie`), breaks (`broken`), and comes back slower with notes missing
while it listens (`watching`). In 05 the music is gone (`room`).
"""
import numpy as np

from synth import (SR, bitcrush, bp, brown, cents, db, hp, lp, midi_hz,
                   music_box, n_of, pad, place, reverb, rng, sine, sweep_bp,
                   swell, thump, times, tri, white, wrap_add, wrap_xfade)

BARS = 8

# One chord per bar, D major. (MIDI notes, bass first.)
CHORDS = [
    [50, 57, 64, 66],  # Dadd9  D3 A3 E4 F#4
    [47, 54, 57, 62],  # Bm7    B2 F#3 A3 D4
    [43, 50, 54, 59],  # Gmaj7  G2 D3 F#3 B3
    [45, 52, 57, 62],  # Asus4  A2 E3 A3 D4 (never resolves)
    [50, 57, 62, 66],  # D      D3 A3 D4 F#4
    [47, 54, 57, 62],  # Bm7
    [52, 55, 59, 62],  # Em7    E3 G3 B3 D4
    [43, 50, 52, 59],  # G6     G2 D3 E3 B3
]

# The lullaby: (beat, MIDI note, beats long) over 32 beats.
MELODY = [
    (0, 78, 1.5), (1.5, 76, .5), (2, 74, 1), (3, 69, 1),
    (4, 71, 1), (5, 74, 1), (6, 78, 1.5), (7.5, 76, .5),
    (8, 74, 1.5), (9.5, 71, .5), (10, 74, 1), (11, 79, 1),
    (12, 76, 2), (14, 69, 1),
    (16, 78, 1.5), (17.5, 76, .5), (18, 74, 1), (19, 81, 1),
    (20, 83, 1.5), (21.5, 81, .5), (22, 78, 1), (23, 74, 1),
    (24, 76, 1), (25, 79, 1), (26, 83, 1), (27, 81, 1),
    (28, 78, 1), (29, 76, 1), (30, 74, 2),
]

# Bar 6's F#5 sags ~40 cents once per loop: the only clue, like "don't".
SAG_BEAT = 22
# The lie: each phrase ends a semitone wrong.
LIE_ENDINGS = {12: 77, 30: 75}  # E5 → F5, D5 → D#5


def lied_melody():
    return [(b, LIE_ENDINGS.get(b, m), d) for b, m, d in MELODY]


def _length(bpm):
    return n_of(BARS * 4 * 60 / bpm)


def _sum(*layers):
    out = np.zeros((2, max(layer.shape[1] for layer in layers)))
    for layer in layers:
        out[:, :layer.shape[1]] += layer
    return out


def _pads(bpm, *, cutoff=1500, wobble=None, gain=0.35, sub=0.15):
    bar = 240 / bpm
    out = np.zeros((2, _length(bpm) + n_of(4)))
    for k, chord in enumerate(CHORDS):
        t0 = k * bar
        tone = pad(chord, bar, attack=0.9, release=1.4, cutoff=cutoff, wobble=wobble, t0=t0)
        place(out, tone * gain, t0)
        m = len(tone)
        t = times(m)
        bass = sine(midi_hz(chord[0] - 12), m) * np.clip(t / 0.3, 0, 1) * np.clip((bar + 0.6 - t) / 0.6, 0, 1)
        place(out, bass * sub, t0)
    return out


def _box(bpm, melody, *, octave=0, gain=0.5, sag=None, sour=0.0, seed=0):
    """Music-box melody. `sag` = beat whose note bends; `sour` = cents of a
    second, detuned voice a hair behind the first."""
    beat = 60 / bpm
    out = np.zeros((2, _length(bpm) + n_of(3)))
    r = rng(seed)
    for i, (b, m, _dur) in enumerate(melody):
        f = midi_hz(m + 12 * octave)
        at = b * beat + r.uniform(0, 0.008)
        vel = gain * r.uniform(0.8, 1.0)
        bend = None
        if b == sag:
            t = times(n_of(2.4))
            bend = cents(-40 * np.sin(np.pi * np.clip(t / 0.9, 0, 1)))
        pan = 0.2 if i % 2 else -0.2
        place(out, music_box(f, 2.4, bend=bend, seed=seed + i) * vel, at, pan=pan)
        if sour:
            place(out, music_box(f * cents(sour), 2.4, seed=seed + 100 + i) * vel * 0.7,
                  at + 0.015, pan=-pan)
    return out


def trust():
    """Menu, 01, 02 before the lie, ending TRUST."""
    bpm = 72
    song = _sum(_pads(bpm), _box(bpm, MELODY, sag=SAG_BEAT, seed=1))
    return wrap_add(reverb(song, 2.4, mix=0.3, seed=3), _length(bpm))


def lie():
    """02 after the lie: the same song, sour, with wrong phrase endings."""
    bpm = 72
    loop_sec = _length(bpm) / SR

    def wobble(t):  # 8 whole cycles per loop, so it loops cleanly
        return 12 * np.sin(2 * np.pi * 8 * t / loop_sec)

    song = _sum(_pads(bpm, cutoff=950, wobble=wobble),
                _box(bpm, lied_melody(), sag=SAG_BEAT, sour=22, seed=11))
    return wrap_add(reverb(song, 2.8, mix=0.34, seed=13), _length(bpm))


def broken():
    """03: fragments, stutters, dropouts over a dissonant drone."""
    bpm = 72
    n = _length(bpm)
    r = rng(21)
    frags = []
    for b, m, d in MELODY:
        roll = r.random()
        if roll < 0.3:
            continue  # dropped
        if roll < 0.55:
            frags += [(b + k * 0.25, m, 0.25) for k in range(3)]  # stutter
        else:
            frags.append((b, m, d))
    box = _box(bpm, frags, gain=0.45, seed=23)
    box = np.vstack([bitcrush(ch, bits=5, hold=6) for ch in box])
    song = wrap_add(reverb(box, 1.8, mix=0.25, seed=27), n)

    m = n + n_of(2.5)
    drone = reverb(pad([38, 50, 51, 57], m / SR, attack=0.01, release=0.01,
                       cutoff=600, detune=9) * 0.8, 2.0, mix=0.3, seed=28)[:, :m]
    hiss = bitcrush(bp(white(m, 24), 2000, 6000), bits=4, hold=3) * db(-30)
    crackle = np.zeros(m)
    r2 = rng(26)
    crackle[r2.integers(0, m, 120)] = r2.uniform(-1, 1, 120) * 0.5
    bed = wrap_xfade(drone + hiss + crackle, n, 2.0)

    out = song + bed * 0.6
    r3 = rng(25)
    for _ in range(6):  # the game loses its grip
        s = n_of(r3.uniform(0.5, n / SR - 0.8))
        out[:, s:s + n_of(r3.uniform(0.08, 0.25))] = 0.0
    return out


def watching():
    """04: back in room 01, slower and lower, with notes missing; a pulse."""
    bpm = 60
    n = _length(bpm)
    keep = [note for i, note in enumerate(MELODY) if i % 5 not in (1, 3)]  # ~40% gone
    song = _sum(_box(bpm, keep, octave=-1, gain=0.4, seed=31),
                _pads(bpm, cutoff=700, gain=0.3, sub=0.12))
    song = wrap_add(reverb(song, 3.2, mix=0.4, seed=33), n)
    heart = np.zeros((2, n + n_of(1)))
    for k in range(BARS * 4):
        place(heart, thump(58), k * 1.0, gain=0.5)
        place(heart, thump(52), k * 1.0 + 0.24, gain=0.3)
    tinnitus = sine(3150, n) * swell(n, 0.55) ** 2 * db(-40)
    return song + wrap_add(heart, n) + tinnitus


def room():
    """05 TRUTH: no music, just the room."""
    L = 16.0
    n, m = n_of(L), n_of(L + 2)
    t = times(m)
    breath = 0.75 + 0.25 * np.sin(2 * np.pi * 2 * t / L)
    hum = (sine(55, m) + 0.4 * sine(110, m) + 0.2 * sine(165, m) + 0.08 * sine(220, m)) * breath * 0.5
    air = np.vstack([hp(lp(brown(m, 40 + ch), 300), 30) * 0.6 for ch in range(2)])
    # The hum and its breathing repeat exactly every L seconds, so only the
    # noise needs the crossfade: equal power on the hum would swell it 3 dB.
    return wrap_xfade(air, n, 2.0) + hum[:n]


def exit_():
    """Ending DON'T TRUST: open air and a distant open fifth."""
    L = 16.0
    n, m = n_of(L), n_of(L + 2)
    t = times(m)
    wind = []
    for ch in range(2):
        center = 700 + 400 * np.sin(2 * np.pi * 3 * t / L + ch) + 150 * np.sin(2 * np.pi * 7 * t / L)
        gust = 0.55 + 0.45 * np.sin(2 * np.pi * 2 * t / L + ch * 0.7) ** 2
        wind.append(sweep_bp(white(m, 50 + ch), center, width=0.9) * gust)
    fifth = lp(tri(midi_hz(38), m) + tri(midi_hz(45), m), 500) * (0.6 + 0.4 * np.sin(2 * np.pi * t / L)) * 0.25
    return wrap_xfade(reverb(np.vstack(wind) + fifth, 3.0, mix=0.35, seed=52), n, 2.0)


def true_end():
    """Ending TRUE: one pure chord, no detune, no noise. It blooms and goes."""
    dur = 14.0
    n = n_of(dur)
    t = times(n)
    env = np.clip(t / 3.0, 0, 1) ** 2 * np.clip((dur - t) / 8.0, 0, 1) ** 1.5
    out = np.zeros((2, n))
    for m, pan in ((50, -0.3), (57, 0.3), (66, -0.15), (76, 0.15), (81, 0.0)):  # D3 A3 F#4 E5 A5
        tone = (sine(midi_hz(m), n) + 0.08 * sine(2 * midi_hz(m), n)) * env / 5
        place(out, tone, 0, pan=pan)
    return reverb(out, 3.0, mix=0.25, seed=61)


# stem → (render, RMS dBFS, peak ceiling dBFS)
MUSIC = {
    'trust': (trust, -24, -6),
    'lie': (lie, -24, -6),
    'broken': (broken, -24, -6),
    'watching': (watching, -24, -6),
    'room': (room, -30, -12),
    'exit': (exit_, -30, -12),
    'true': (true_end, -22, -6),
}
ONE_SHOTS = {'true'}
