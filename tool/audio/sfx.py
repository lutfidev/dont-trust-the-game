"""The game's sound effects. Each function returns a mono float array; SFX
maps the file stem to (render, peak dBFS). The spec's SFX table says when
each one plays."""
import numpy as np

from synth import (bitcrush, bp, brown, decay, drive, hp, lp, metal, midi_hz,
                   music_box, n_of, place, ramp, reverb, rng, saw, sine,
                   square, swell, sweep_bp, times, tri, white)


# ---------------------------------------------------------------- UI

def click():
    n = n_of(0.03)
    return (hp(white(n, 1), 2000) * decay(n, 0.008) * 0.7
            + sine(1800, n) * decay(n, 0.012) * 0.4
            + sine(160, n) * decay(n, 0.02) * 0.3)


def deny():
    """"NO." — a low descending two-tone blip."""
    out = np.zeros(n_of(0.3))
    for k, m in enumerate((64, 59)):  # E4 → B3
        n = n_of(0.09)
        place(out, lp(square(midi_hz(m), n, 9), 1800) * ramp(n, 0.004, 0.03), k * 0.12)
    return out


def _blip(midis):
    out = np.zeros(n_of(0.2))
    for k, m in enumerate(midis):
        n = n_of(0.06)
        place(out, tri(midi_hz(m), n) * ramp(n, 0.004, 0.03), k * 0.07)
    return out


def pause():
    return _blip((81, 76))  # A5 → E5: the game holds its breath


def resume():
    return _blip((76, 81))


# ---------------------------------------------------------------- boot / terminal

def boot_tick():
    n = n_of(0.05)
    return hp(white(n, 3), 1500) * decay(n, 0.006) + sine(120, n) * decay(n, 0.025) * 0.5


def boot_ok():
    n = n_of(0.12)
    return sine(1318.5, n) * ramp(n, 0.005, 0.0) * decay(n, 0.12)


def hello():
    """The lullaby's instrument, introduced: D5 F#5 A5."""
    out = np.zeros(n_of(1.4))
    for k, m in enumerate((74, 78, 81)):
        place(out, music_box(midi_hz(m), 1.2, seed=k), k * 0.12, gain=1 - k * 0.1)
    return reverb(out, 1.6, mix=0.3, stereo=False)


def type_():
    n = n_of(0.02)
    return bp(white(n, 5), 2000, 6000) * decay(n, 0.004) + sine(900, n) * decay(n, 0.006) * 0.3


def good():
    """Positive reinforcement, a little too sweet: A5 → D6."""
    out = np.zeros(n_of(1.2))
    place(out, music_box(midi_hz(81), 1.1, seed=1), 0.0)
    place(out, music_box(midi_hz(86), 1.1, seed=2), 0.16)
    return reverb(out, 1.4, mix=0.3, stereo=False)


def lie():
    """"I LIED.": noise sucked in backwards, a detuned low hit, a crushed tail."""
    swell_dur = 0.35
    out = np.zeros(n_of(2.2))
    ns = n_of(swell_dur)
    place(out, lp(white(ns, 11), 3000) * np.linspace(0, 1, ns) ** 3 * 0.5, 0)
    n = n_of(1.6)
    hit = (sine(55, n) * 0.9 + lp(saw(110, n) + saw(116.5, n), 900) * 0.5) * decay(n, 1.4)
    a = n_of(0.003)
    hit[:a] *= np.linspace(0, 1, a)
    place(out, hit, swell_dur)
    place(out, bitcrush(hit, bits=3, hold=10) * decay(n, 0.8) * 0.25, swell_dur + 0.05)
    return out


def voice():
    """The serif voice arrives: a low breath."""
    n = n_of(1.3)
    return bp(white(n, 13), 300, 1200) * swell(n, 0.3) * 0.5 + sine(98, n) * swell(n, 0.35) * 0.35


# ---------------------------------------------------------------- the room

def step(pitch=1.0, seed=17):
    n = n_of(0.09)
    return (lp(white(n, seed), 600 * pitch) * decay(n, 0.025) * 0.8
            + sine(80 * pitch, n) * decay(n, 0.04) * 0.6)


def step_watch():
    """04: the same step, lower, and the room answers."""
    dry = step(0.85, seed=19)
    out = np.zeros(n_of(0.45))
    place(out, dry, 0)
    place(out, lp(dry, 500), 0.12, gain=0.35)
    place(out, lp(dry, 400), 0.24, gain=0.12)
    return out


def _metal_click(seed, base=1.0):
    return metal([1200 * base, 2700 * base, 4100 * base], 0.05, seed)


def door_locked():
    out = np.zeros(n_of(0.6))
    for r, t in enumerate((0.0, 0.18)):
        for k in range(3):
            place(out, _metal_click(30 + r * 3 + k, 1 + 0.03 * k), t + k * 0.025, gain=0.6)
    n = n_of(0.2)
    place(out, sine(110, n) * decay(n, 0.12) + lp(white(n, 40), 400) * decay(n, 0.06), 0.36)
    return out


def door_open():
    out = np.zeros(n_of(1.0))
    place(out, _metal_click(41), 0.0)
    n = n_of(0.62)
    t = times(n)
    f = 380 + 140 * t / t[-1]  # the creak rises
    friction = np.clip(np.sin(2 * np.pi * 34 * t), 0, 1) ** 2  # stick-slip
    place(out, bp(saw(f, n, 8) * friction, 300, 2000) * swell(n, 0.4) * 0.7, 0.08)
    m = n_of(0.9)
    place(out, lp(white(m, 42), 800) * swell(m, 0.5) * 0.3, 0.1)
    return out


def drawer_open():
    out = np.zeros(n_of(0.7))
    n = n_of(0.45)
    grain = 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 23 * times(n)))  # wood judder
    slide = bp(brown(n, 50) + white(n, 51) * 0.3, 200, 1500) * grain * ramp(n, 0.04, 0.08)
    place(out, slide, 0)
    m = n_of(0.12)
    place(out, sine(90, m) * decay(m, 0.08) + lp(white(m, 52), 300) * decay(m, 0.04), 0.47)
    return out


def key():
    out = np.zeros(n_of(0.6))
    place(out, metal([2350, 3620, 5210, 6980], 0.35, seed=60), 0.0)
    place(out, metal([2380, 3650, 5180, 7020], 0.3, seed=61), 0.09, gain=0.7)
    return out


def crack():
    out = np.zeros(n_of(1.6))
    n = n_of(1.4)
    place(out, lp(lp(brown(n, 70), 120), 120) * swell(n, 0.2), 0)
    r = rng(71)
    for k in range(25):
        g = n_of(r.uniform(0.005, 0.015))
        grit = hp(white(g, 72 + k), 1000) * decay(g, 0.01)
        place(out, grit, 0.1 + 0.9 * (k / 25) ** 1.6, gain=r.uniform(0.2, 0.6) * (1 - k / 30))
    return out


# ---------------------------------------------------------------- the puzzle

def dial():
    n = n_of(0.03)
    return hp(white(n, 80), 3000) * decay(n, 0.003) * 0.6 + sine(2200, n) * decay(n, 0.01) * 0.5


def _buzz(f2=None):
    n = n_of(0.11)
    x = square(110, n, 25)
    if f2:
        x = x + square(f2, n, 25)
    return lp(x, 1200) * ramp(n, 0.005, 0.02)


def wrong():
    out = np.zeros(n_of(0.32))
    place(out, _buzz(), 0)
    place(out, _buzz(), 0.17)
    return out


def wrong_lied():
    """1-2-3-4: the buzz you were promised, sour and breaking."""
    out = np.zeros(n_of(0.5))
    place(out, drive(_buzz(116.5), 4), 0)
    n = n_of(0.3)
    f = 110 * (1 - 0.35 * times(n) / 0.3)  # sags
    last = lp(square(f, n, 25) + square(f * 1.06, n, 25), 1200) * ramp(n, 0.005, 0.08)
    place(out, bitcrush(drive(last, 4), bits=4, hold=6), 0.17)
    return out


def unlock():
    out = np.zeros(n_of(1.4))
    place(out, _metal_click(90, 0.8), 0)
    n = n_of(0.08)
    place(out, sine(140, n) * decay(n, 0.05) * 0.6, 0)
    chime = music_box(midi_hz(81), 1.1, seed=91) + music_box(midi_hz(86), 1.1, seed=92)
    place(out, chime * 0.6, 0.1)
    return reverb(out, 1.2, mix=0.25, stereo=False)


# ---------------------------------------------------------------- glitch / transitions

def glitch_light():
    n = n_of(0.12)
    x = bitcrush(bp(white(n, 100), 1000, 7000), bits=3, hold=14)
    gate = np.zeros(n)
    r = rng(101)
    for _ in range(3):
        s = int(r.integers(0, n - n_of(0.025)))
        gate[s:s + n_of(r.uniform(0.01, 0.03))] = 1
    return x * gate


def glitch_heavy():
    out = np.zeros(n_of(0.28))
    r = rng(110)
    m = n_of(0.03)
    grain = square(440, m, 12) * 0.5 + white(m, 111) * 0.5
    for k in range(6):
        place(out, bitcrush(grain, bits=3, hold=int(r.integers(2, 12))) * 0.8,
              k * 0.04 + r.uniform(0, 0.008))
    n = len(out)
    return out + lp(square(60, n, 20), 400) * 0.35 * ramp(n, 0.005, 0.05)


def tear():
    """Static ripping shut, 500 → 6000 Hz, breaking up; hard cut at full cover."""
    n = n_of(0.38)
    t = times(n) / 0.38
    x = sweep_bp(white(n, 120), 500 * 12 ** t) * t ** 1.5
    x = x * (1 - t) + bitcrush(x, bits=4, hold=3) * t
    a = n_of(0.003)
    x[-a:] *= np.linspace(1, 0, a)
    return x


def tear_open():
    n = n_of(0.3)
    t = times(n) / 0.3
    x = bitcrush(sweep_bp(white(n, 130), 500 * 12 ** t) * t ** 1.5, bits=5, hold=2)
    return x[::-1].copy()


def light():
    """A rising sweep into white: shimmer, then a soft hum under the card."""
    out = np.zeros(n_of(1.8))
    n = n_of(0.45)
    t = times(n) / 0.45
    place(out, sine(200 * 8 ** t, n) * t ** 2 * 0.4 + hp(white(n, 140), 2000) * t ** 3 * 0.3, 0)
    m = n_of(1.35)
    tm = times(m)
    shimmer = sum(sine(midi_hz(p), m) * (0.5 + 0.5 * np.sin(2 * np.pi * rate * tm))
                  for p, rate in ((86, 5.1), (93, 6.3), (100, 7.7))) / 3
    hum = sine(110, m) * 0.3
    place(out, (shimmer * decay(m, 0.9) + hum * ramp(m, 0.05, 0.6)) * 0.8, 0.45)
    return reverb(out, 1.5, mix=0.3, stereo=False)


def fade():
    """REDUCE GLITCH transitions: a soft low whoosh."""
    n = n_of(0.6)
    return lp(white(n, 150), 900) * swell(n, 0.5)


# Peak targets (dBFS): ticks −24, UI −15, world −9…−12, events −4…−7.
SFX = {
    'click': (click, -15),
    'deny': (deny, -17),
    'boot_tick': (boot_tick, -24),
    'boot_ok': (boot_ok, -16),
    'hello': (hello, -9),
    'type': (type_, -24),
    'good': (good, -10),
    'lie': (lie, -4),
    'voice': (voice, -12),
    'step': (step, -12),
    'step_watch': (step_watch, -12),
    'door_locked': (door_locked, -9),
    'door_open': (door_open, -9),
    'drawer_open': (drawer_open, -9),
    'key': (key, -10),
    'crack': (crack, -5),
    'dial': (dial, -14),
    'wrong': (wrong, -15),  # dense buzz: keep its RMS under the lie sting
    'wrong_lied': (wrong_lied, -14),
    'unlock': (unlock, -9),
    'glitch_light': (glitch_light, -22),
    'glitch_heavy': (glitch_heavy, -18),
    'tear': (tear, -5),
    'tear_open': (tear_open, -7),
    'light': (light, -6),
    'fade': (fade, -12),
    'pause': (pause, -15),
    'resume': (resume, -15),
}
