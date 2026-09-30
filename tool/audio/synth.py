"""A tiny offline synth for the game's audio.

Signals are float64 numpy arrays at SR: mono is shape (n,), stereo (2, n).
Everything random takes an explicit seed, so renders are reproducible.
"""
import numpy as np
from scipy import signal

SR = 44100
NYQ = SR * 0.45  # keep filters and partials safely below Nyquist


# ---------------------------------------------------------------- units

def n_of(sec):
    """Samples in `sec` seconds (at least 1)."""
    return max(1, int(round(sec * SR)))


def times(n):
    return np.arange(n) / SR


def midi_hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def cents(c):
    """Frequency ratio for `c` cents (scalar or array)."""
    return 2.0 ** (np.asarray(c, dtype=float) / 1200.0)


def db(x):
    return 10.0 ** (x / 20.0)


def rng(seed):
    return np.random.default_rng(seed)


# ---------------------------------------------------------------- envelopes

def decay(n, t60):
    """Exponential decay that is 60 dB down after `t60` seconds."""
    return np.exp(-6.907755 * np.arange(n) / (t60 * SR))


def ramp(n, attack, release):
    """1 with a linear attack and release (seconds) at the ends."""
    env = np.ones(n)
    a, r = min(n, n_of(attack)), min(n, n_of(release))
    env[:a] *= np.linspace(0, 1, a, endpoint=False)
    env[n - r:] *= np.linspace(1, 0, r)
    return env


def swell(n, peak=0.5):
    """Smooth 0 → 1 → 0 hump peaking at fraction `peak` of the length."""
    x = np.linspace(0, 1, n)
    rise = np.clip(x / peak, 0, 1)
    fall = np.clip((1 - x) / (1 - peak), 0, 1)
    return np.sin(np.minimum(rise, fall) * np.pi / 2) ** 2


# ---------------------------------------------------------------- sources

def phase(freq, n):
    """Running phase in radians for a constant or per-sample frequency."""
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    return 2 * np.pi * np.cumsum(f) / SR


def sine(freq, n):
    return np.sin(phase(freq, n))


def partials(freq, n, amps):
    """Additive tone; amps[k] is the level of harmonic k + 1. Harmonics that
    would pass Nyquist are left out, so it never aliases."""
    ph = phase(freq, n)
    top = float(np.max(freq))
    out = np.zeros(n)
    for k, a in enumerate(amps, start=1):
        if a and top * k < NYQ:
            out += a * np.sin(k * ph)
    return out


def saw(freq, n, harmonics=12):
    return partials(freq, n, [1 / k for k in range(1, harmonics + 1)]) * 0.6


def square(freq, n, harmonics=15):
    return partials(freq, n, [1 / k if k % 2 else 0 for k in range(1, harmonics + 1)]) * 0.8


def tri(freq, n):
    return partials(freq, n, [(-1) ** (k // 2) / k ** 2 if k % 2 else 0 for k in range(1, 12)])


def white(n, seed):
    return rng(seed).uniform(-1, 1, n)


def brown(n, seed):
    """Deep rumbling noise (leaky-integrated white), peak-normalized."""
    x = signal.lfilter([1.0], [1.0, -0.997], rng(seed).standard_normal(n))
    x -= x.mean()
    return x / (np.max(np.abs(x)) + 1e-12)


# ---------------------------------------------------------------- filters

def _sos(kind, fc, order):
    return signal.butter(order, fc, btype=kind, fs=SR, output='sos')


def lp(x, fc, order=2):
    return signal.sosfilt(_sos('lowpass', min(fc, NYQ), order), x)


def hp(x, fc, order=2):
    return signal.sosfilt(_sos('highpass', fc, order), x)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(_sos('bandpass', [lo, min(hi, NYQ)], order), x)


def sweep(x, design, block=256):
    """Filters mono `x` with coefficients re-designed every block;
    design(sample_index) -> (b, a)."""
    out = np.zeros(len(x))
    zi = None
    for s in range(0, len(x), block):
        b, a = design(s)
        if zi is None:
            zi = np.zeros(max(len(a), len(b)) - 1)
        out[s:s + block], zi = signal.lfilter(b, a, x[s:s + block], zi=zi)
    return out


def sweep_bp(x, centers, width=0.6, block=256):
    """Band-pass following per-sample `centers` (Hz); band = center·(1 ± width/2)."""
    def design(s):
        c = float(np.clip(centers[s], 80, NYQ / (1 + width / 2)))
        return signal.butter(1, [c * (1 - width / 2), c * (1 + width / 2)],
                             btype='bandpass', fs=SR)
    return sweep(x, design, block)


# ---------------------------------------------------------------- effects

def bitcrush(x, bits=4, hold=4):
    """Lo-fi (mono): hold every `hold`-th sample and quantize to `bits`."""
    y = np.repeat(x[::hold], hold)[:len(x)]
    q = 2 ** (bits - 1)
    return np.round(y * q) / q


def drive(x, amount=3.0):
    return np.tanh(x * amount) / np.tanh(amount)


def reverb(x, sec=2.0, mix=0.25, damp=5000, seed=7, stereo=True):
    """Convolution reverb with a synthetic impulse (decaying, darkened noise).

    x is mono (n,) or stereo (2, n). Returns stereo (2, m), or mono (m,) when
    stereo=False, where m = n + the tail; dry and wet are mixed.
    """
    chans = 2 if stereo else 1
    src = np.atleast_2d(x)
    if src.shape[0] != chans:
        src = np.repeat(src.mean(axis=0, keepdims=True), chans, axis=0)
    r = rng(seed)
    n_ir, pre = n_of(sec), n_of(0.012)
    out = np.zeros((chans, src.shape[1] + pre + n_ir))
    for ch in range(chans):
        ir = lp(r.standard_normal(n_ir) * decay(n_ir, sec), damp)
        ir /= np.sqrt(np.sum(ir ** 2))
        wet = signal.fftconvolve(src[ch], ir)
        out[ch, pre:pre + len(wet)] += wet * mix
        out[ch, :src.shape[1]] += src[ch] * (1 - mix)
    return out if stereo else out[0]


# ---------------------------------------------------------------- instruments

# (frequency ratio, level, share of the note's length it rings) per partial.
MUSIC_BOX = [(1.0, 1.0, 1.0), (2.0, 0.10, 0.5), (5.93, 0.22, 0.14), (9.1, 0.06, 0.08)]


def music_box(freq, dur=2.4, bend=None, seed=0):
    """A music-box tine: inharmonic partials whose highs die fast, plus a
    tiny pluck. `bend` is an optional per-sample frequency ratio."""
    n = n_of(dur)
    f = freq * (bend if bend is not None else 1.0)
    out = np.zeros(n)
    for ratio, amp, life in MUSIC_BOX:
        if freq * ratio < NYQ:
            out += amp * sine(f * ratio, n) * decay(n, dur * life)
    pluck = hp(white(n_of(0.004), seed), 2500) * 0.15
    out[:len(pluck)] += pluck
    a = n_of(0.002)
    out[:a] *= np.linspace(0, 1, a)
    return out


def pad(midis, dur, *, attack=1.0, release=1.5, cutoff=1500, detune=6, wobble=None, t0=0.0):
    """Warm chord: three detuned band-limited saws per note, low-passed, with
    a smooth attack/release. Lasts dur + release seconds. `wobble(t)` returns
    a pitch bend in cents for absolute time t (t0 = this chord's start)."""
    n = n_of(dur + release)
    t = times(n)
    bend = cents(wobble(t + t0)) if wobble else 1.0
    out = np.zeros(n)
    for m in midis:
        for d in (-detune, 0, detune):
            out += saw(midi_hz(m) * cents(d) * bend, n, harmonics=10)
    out = lp(out, cutoff) / (3 * len(midis))
    rise = np.clip(t / attack, 0, 1)
    fall = np.clip((t - dur) / release, 0, 1)
    return out * np.sin(rise * np.pi / 2) * np.cos(fall * np.pi / 2)


def metal(freqs, dur, seed=0):
    """Struck metal: a few inharmonic partials with uneven decays and a tick."""
    n = n_of(dur)
    r = rng(seed)
    out = np.zeros(n)
    for k, f in enumerate(freqs):
        out += sine(f * r.uniform(0.99, 1.01), n) * decay(n, dur * r.uniform(0.4, 1.0)) / np.sqrt(k + 1)
    tick = hp(white(n_of(0.003), seed), 3000) * 0.3
    out[:len(tick)] += tick
    return out


def thump(freq=58.0, dur=0.25):
    """A soft low thump whose pitch drops as it hits (heartbeat, footfalls)."""
    n = n_of(dur)
    f = freq * (1 + 0.6 * decay(n, 0.04))
    body = sine(f, n) + 0.35 * sine(2 * f, n)
    return body * decay(n, dur) * np.clip(times(n) / 0.004, 0, 1)


# ---------------------------------------------------------------- arranging

def place(buf, snd, at, gain=1.0, pan=0.0):
    """Adds `snd` into `buf` starting at `at` seconds (cut at the end).
    Mono into stereo uses an equal-power pan in [-1, 1] (0 = unity both sides)."""
    i = int(round(at * SR))
    if i >= buf.shape[-1]:
        return
    m = min(snd.shape[-1], buf.shape[-1] - i)
    if buf.ndim == 1:
        src = snd if snd.ndim == 1 else snd.mean(axis=0)
        buf[i:i + m] += src[:m] * gain
    elif snd.ndim == 1:
        th = (pan + 1) * np.pi / 4
        buf[0, i:i + m] += snd[:m] * gain * np.cos(th) * np.sqrt(2)
        buf[1, i:i + m] += snd[:m] * gain * np.sin(th) * np.sqrt(2)
    else:
        buf[:, i:i + m] += snd[:, :m] * gain


def wrap_add(buf, n):
    """Folds everything after n samples back onto the start, so note and
    reverb tails carry across the loop point exactly as in a real repeat."""
    out = buf[..., :n].copy()
    tail = buf[..., n:]
    while tail.shape[-1]:
        m = min(n, tail.shape[-1])
        out[..., :m] += tail[..., :m]
        tail = tail[..., m:]
    return out


def wrap_xfade(buf, n, xfade):
    """Loops continuous material (noise beds, drones): the audio after n
    samples is crossfaded (equal power) into the start. Needs n + xfade.
    Equal power suits uncorrelated material; anything that repeats exactly
    every n samples comes out up to 3 dB louder, so add it after instead."""
    out = buf[..., :n].copy()
    k = n_of(xfade)
    t = np.linspace(0, 1, k)
    out[..., :k] = out[..., :k] * np.sin(t * np.pi / 2) + buf[..., n:n + k] * np.cos(t * np.pi / 2)
    return out


# ---------------------------------------------------------------- levels

def peak_db(x):
    return 20 * np.log10(np.max(np.abs(x)) + 1e-12)


def rms_db(x):
    return 20 * np.log10(np.sqrt(np.mean(np.square(x))) + 1e-12)


def to_peak(x, target_db):
    return x * (db(target_db) / (np.max(np.abs(x)) + 1e-12))


def to_rms(x, target_db, ceiling_db):
    """Scales to the target RMS, then lowers it if the peak would pass the ceiling."""
    y = x * (db(target_db) / (np.sqrt(np.mean(np.square(x))) + 1e-12))
    p = np.max(np.abs(y))
    return y * (db(ceiling_db) / p) if p > db(ceiling_db) else y


def trim_tail(x, floor_db=-66):
    """Drops the near-silent end, keeping 10 ms after the last loud sample."""
    env = np.max(np.abs(np.atleast_2d(x)), axis=0)
    loud = np.nonzero(env > env.max() * db(floor_db))[0]
    end = min(env.size, (loud[-1] + 1 if loud.size else 1) + n_of(0.01))
    return x[..., :end]


def edges(x, fade_out=0.005):
    """Short fade at the end so a one-shot never stops with a click."""
    y = x.copy()
    k = min(y.shape[-1], n_of(fade_out))
    y[..., -k:] *= np.linspace(1, 0, k)
    return y
