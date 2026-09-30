"""Renders all of the game's sound into assets/audio/.

Everything is synthesized here from oscillators and noise (no samples), with
fixed seeds, so every run gives the same files.

    python -m venv tool/audio/.venv
    tool/audio/.venv/Scripts/pip install -r tool/audio/requirements.txt   # bin/ on macOS/Linux
    tool/audio/.venv/Scripts/python tool/audio/generate_audio.py [name ...]

Pass names (e.g. `click trust`) to render only those.
"""
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

import music
import sfx
from synth import SR, edges, peak_db, rms_db, to_peak, to_rms, trim_tail

OUT = Path(__file__).resolve().parents[2] / 'assets' / 'audio'


def write_sfx(name, render, peak):
    x = to_peak(edges(trim_tail(render())), peak)
    path = OUT / 'sfx' / f'{name}.wav'
    sf.write(path, x, SR, subtype='PCM_16')
    return path, x


def write_music(name, render, rms, ceiling):
    x = render()
    if name in music.ONE_SHOTS:
        x = edges(trim_tail(x), 0.05)  # loops must stay exactly one cycle
    x = to_rms(x, rms, ceiling)
    path = OUT / 'music' / f'{name}.ogg'
    # In blocks: one big write overflows the stack inside libsndfile's Vorbis
    # encoder (Windows).
    with sf.SoundFile(path, 'w', SR, 2, format='OGG', subtype='VORBIS',
                      compression_level=0.75) as f:
        for i in range(0, x.shape[1], 8192):
            f.write(x[:, i:i + 8192].T)
    return path, x


def main(only):
    for d in ('sfx', 'music'):
        (OUT / d).mkdir(parents=True, exist_ok=True)
    rows = [write_sfx(name, render, peak)
            for name, (render, peak) in sfx.SFX.items() if not only or name in only]
    rows += [write_music(name, render, rms, ceiling)
             for name, (render, rms, ceiling) in music.MUSIC.items() if not only or name in only]
    report(rows)


def report(rows):
    print(f"{'file':<24}{'sec':>7}{'peak dB':>9}{'rms dB':>8}{'KB':>7}")
    for path, x in rows:
        assert np.all(np.isfinite(x)), path
        label = f'{path.parent.name}/{path.name}'
        print(f'{label:<24}{x.shape[-1] / SR:>7.2f}{peak_db(x):>9.1f}{rms_db(x):>8.1f}'
              f'{path.stat().st_size / 1024:>7.0f}')


if __name__ == '__main__':
    main(set(sys.argv[1:]))
