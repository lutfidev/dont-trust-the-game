# Audio

All music and sound effects in this folder are original. They are
synthesized by `tool/audio/generate_audio.py` from oscillators and noise:
no third-party samples, loops or presets. They carry the same licence as
the rest of the project.

- `music/*.ogg`: Vorbis, 44.1 kHz stereo. Every file except `true.ogg`
  loops seamlessly.
- `sfx/*.wav`: 44.1 kHz mono, 16-bit.

To change a sound, edit `tool/audio/sfx.py` or `tool/audio/music.py` and
re-run the generator (see the project README, "Audio").
