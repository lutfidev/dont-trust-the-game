# Audio design — Don't Trust The Game

Date: 2026-09-30 · Status: approved in chat, awaiting spec review

## Goal

Give the game music and sound effects that carry its story: a game that
pretends to help, lies, breaks, watches you, and finally goes quiet. Audio
must be legally safe, never overbearing, balanced between music and SFX,
and change at the story's key moments. Gameplay, UI and existing features
stay as they are.

**Said by the user:** BGM + SFX; legal/no copyright risk; mysterious, uneasy,
unpredictable where it fits; not excessive; balanced; dynamic variation at
key moments; keep everything else unchanged.

**Assumed (confirmed in chat):** Android/iOS first, web keeps working; the
existing MUSIC/SFX settings (stored, unused today) become live; REDUCE
GLITCH also calms glitch sounds; vibration is unchanged.

## Concept: the lullaby that lies

The game has one musical voice: a gentle music-box lullaby over a warm pad,
friendly like an onboarding tune — *too* friendly, the way "I WILL HELP YOU."
is. As trust erodes, the **same song** decays instead of being swapped for
other music. When the game finally says "The game cannot control you if you
stop listening", the music has already stopped.

All audio is **original**: synthesized by a script in this repo
(`tool/audio/generate_audio.py`). No third-party samples, loops or presets,
so there is nothing to license or attribute.

## Music moods

One music loop plays at a time. `Mood` is derived from game state by a pure
function (see *Architecture*). Key D major, music box + pad unless noted.

| Mood | Asset | When | Character |
| --- | --- | --- | --- |
| `silence` | — | boot; after "I LIED." while `[ CONTINUE ]` is shown | nothing |
| `trust` | `music/trust.ogg` | main menu, 01, 02 before the lie, ending TRUST | 72 BPM, 8 bars (~26.7 s). Clean lullaby. Once per loop (bar 6) one note sags ~40 cents and recovers — the only musical clue, like the scrawled "don't". |
| `lie` | `music/lie.ogg` | 02 after `[ CONTINUE ]` ("DON'T GO THERE.") | Same song, same length. Music box detuned against itself (sour chorus), the last note of each phrase a semitone wrong, pad pitch wobbles slowly, darker filter. |
| `broken` | `music/broken.ogg` | 03 UI GLITCH | Same tempo. Melody fragments bitcrushed and stuttered, seeded dropouts, dissonant drone (D–E♭–A) with sub, faint digital noise bed. |
| `watching` | `music/watching.ogg` | 04 WATCHING | 60 BPM, 8 bars (~32 s). The room-01 song slower and lower with ~40% of the notes missing (it's listening), a soft low "lub-dub" pulse, a faint high tone swelling in and out. |
| `room` | `music/room.ogg` | 05 TRUTH and the choice | No music: ~16 s room-tone loop (low hum partials + filtered brown noise, slow breathing amplitude). |
| `exit` | `music/exit.ogg` | ending DON'T TRUST | ~16 s loop: open-air wind (modulated band-passed noise, gusts) and a distant open fifth (D–A). |
| `truthEnd` | `music/true.ogg` (one-shot) | ending TRUE | Current audio fades out; ~1.5 s of silence; then one pure, consonant D-major(add9) chord blooms (~14 s, sine/triangle, no detune, no noise) and fades to silence. The first sound that isn't trying to control you. |

**Mood changes**

- Default: old loop fades out, new loop fades in (per-mood fade times,
  ~0.8–2.5 s).
- Ending TRUST: hard cut straight into `trust` at full level, as if nothing
  happened; the 4.2 s loop back to 01 keeps the same voice playing (no
  restart).
- **The lie** ("I LIED."): *tape-stop* — the music's play speed and volume
  fall to a halt over ~0.9 s (pitch dives), with the `lie` sting on top. Mood
  is `silence` while the `[ CONTINUE ] / [ LOG ]` prompt is up. On
  `[ CONTINUE ]` the `lie` loop fades in with "DON'T GO THERE."
- **Stage transitions**: music fades out while the screen is being covered,
  stays silent under the stage card, and the new mood starts as the screen
  is revealed.
- **Glitch bursts** (natural ones from `GlitchDirector`, 02-after-lie/03/04):
  the music "hiccups" — play speed jumps to 0.95 (light) / 0.88 (heavy) and
  eases back to 1.0 over ~180 ms — plus a glitch SFX. Forced bursts (at
  transitions and right after the lie) make no glitch sound; those moments
  have their own sounds.
- **Pause**: music bus ducks to 30% over 250 ms; restores on resume.
- Main menu plays `trust`; START → boot sets `silence`; leaving the game
  (back to menu) sets `trust` and un-ducks.

## Sound effects

All SFX are short mono WAVs. "Cooldown" = minimum ms between two plays of
the same sound (extra plays are dropped). "Vary" = random ± play-rate per
play so repeats don't sound identical.

| Sfx | Trigger | Character | Cooldown / vary |
| --- | --- | --- | --- |
| `click` | any `BlockButton` / `HudButton` tap; settings cells, toggles, text speed, reset | soft ~30 ms tick | 40 / ±4% |
| `deny` | "LET THE GAME HELP YOU" turns itself back on ("NO.") | low descending two-tone blip | — |
| `bootTick` | each boot check line appears | soft relay tick | — / ±3% |
| `bootOk` | each boot "OK" appears | tiny sine blip | — |
| `hello` | boot "HELLO." starts typing | music-box D–F♯–A arpeggio (the lullaby's instrument) | — |
| `type` | terminal / boot / stage-card character typed (not spaces; sys and cmd lines only) | very soft key tick | 45 / ±8% |
| `good` | a `LineKind.ok` line ("GOOD."); ending TRUST | two-note rising music-box chime | — |
| `lie` | a `LineKind.lie` line ("I LIED.") | low detuned hit with a reversed-noise swell into it and a bitcrushed tail | — |
| `voice` | a `LineKind.voice` line (serif voice) | low breathy swell (~1.2 s) | — |
| `step` | each tile walked (01–03) | muffled footstep; alternating rate 0.96 / 1.04 | — |
| `stepWatch` | each tile walked in 04 | same step, lower, with a faint baked-in echo | — |
| `doorLocked` | door tapped while locked ("IT'S LOCKED.", "LOCKED.") | handle rattle ×2 + clunk | — |
| `doorOpen` | door opens (03); ending DON'T TRUST | latch click, short creak, air | — |
| `drawerOpen` | drawer opens after the correct code | wooden slide + stop thud | — |
| `key` | key picked up | small metallic jingle | — |
| `crack` | player reaches the crack (04 → 05) | low rumble + crumbling grains | — |
| `dial` | puzzle dial ▲ / ▼ | mechanical tick (rate 1.08 up / 0.94 down) | 30 |
| `wrong` | UNLOCK with a wrong code | two short low buzzes | — |
| `wrongLied` | UNLOCK with the told code 1-2-3-4 | same buzz, distorted and detuned | — |
| `unlock` | UNLOCK with the real code | latch clack + small bright chime | — |
| `glitchLight` | natural light glitch burst | ~120 ms digital crackle | 900 / ±12% |
| `glitchHeavy` | natural heavy glitch burst (03) | ~250 ms stutter | 900 / ±12% |
| `tear` | tear transition starts (02 → 03) | static rip rising to a hard cut at full cover (~380 ms) | — |
| `tearOpen` | tear transition reveal starts | reversed rip (~300 ms) | — |
| `light` | light transition starts (03 → 04, 04 → 05) | rising sweep into a bright shimmer, a soft "white" hum under the card, fading out (~1.7 s) | — |
| `fade` | any transition with REDUCE GLITCH on | soft low whoosh (~0.6 s), no rip | — |
| `pause` / `resume` | pause opened / closed | soft descending / ascending two-note blip | — |

**Not excessive — the rules**

- Typing ticks are throttled (≥45 ms, spaces skipped, very low level) and
  only for sys/cmd lines; ok/lie/voice lines get their one cue instead.
- Glitch SFX are rate-limited (≥900 ms) and sit well under the music.
- Only one music loop at a time (plus a crossfade).
- REDUCE GLITCH (setting or OS reduce-motion): there are no natural bursts,
  so no glitch SFX and no music hiccups; transitions use `fade` instead of
  `tear` / `tearOpen` / `light`. The tape-stop stays (it isn't flicker).
- A global limiter on the output prevents clipping when sounds stack.

## Mixing and volume

- Two mixing buses: **music** and **SFX**. The MUSIC and SFX settings drive
  the bus volumes live (including from the pause → settings screen).
- Setting → gain: `0` is mute; otherwise `gain = 10^((v − 10) · 3 / 20)`,
  i.e. 10 = 0 dB, 8 = −6 dB, 6 = −12 dB, 1 = −27 dB. Defaults stay MUSIC 6,
  SFX 8, so music sits under the feedback sounds.
- **Mute**: tapping the first volume cell while the value is already 1 sets
  it to 0. No visual change (0 cells lit). Today the minimum is 1.
- Assets are normalized by the generator to per-category targets:
  - music loops: RMS ≈ −24 dBFS, peak ≤ −6 dBFS;
  - ambiences (`room`, `exit`): RMS ≈ −30 dBFS;
  - SFX peaks: `type` / `bootTick` ≈ −24 dBFS, `click` and UI blips ≈ −15 dBFS,
    world sounds ≈ −9 dBFS, events (`lie`, transitions, `crack`) ≈ −4 dBFS.
  The generator prints a peak/RMS table so levels are checked by
  measurement. **They must still be verified by ear on a device** (the
  author of this spec could not listen).
- App lifecycle: when the app is hidden/paused the audio device stops (voices
  keep their position); it restarts on resume.

## Architecture

### Runtime (`lib/audio/`)

- `cues.dart` — `enum Sfx` (asset, cooldown, vary) and `enum Mood` (asset,
  looping, fade-in); `double volumeGain(int level)`.
- `game_audio.dart` — the domain-level interface the game talks to, plus
  `SilentAudio` (no-ops; the default everywhere, so tests need no native
  audio) and `AudioScope` (an `InheritedWidget`; `AudioScope.of(context)`
  falls back to `SilentAudio`):

  ```dart
  abstract class GameAudio {
    void play(Sfx sfx, {double rate = 1});
    void mood(Mood mood);          // no-op if unchanged
    void tapeStop();               // the lie
    void hiccup({required bool heavy});
    void cover(Duration fade);     // transition: fade out and hold moods
    void uncover();                // start the mood set while covered
    void duck(bool on);            // pause
  }
  ```

- `audio_director.dart` — `AudioDirector implements GameAudio`: all of the
  audio logic, talking to the engine only through an `AudioBackend` port,
  so it is unit-tested with a fake backend:
  - `start()` runs in the background after `runApp` (no startup delay).
    Calls made before the engine is ready are dropped, except `mood`, which
    is remembered and applied once ready.
  - Any engine/load failure is caught and logged; the game continues silent.
  - Crossfades, tape-stop, hiccups, cover/uncover, ducking, cooldowns and
    play-rate variation.
  - Listens to `SettingsStore`: bus volumes; plays `deny` when `assist`
    flips back on.
  - `suspend()` / `resume()` for the app lifecycle (`AppLifecycleListener`
    in `main.dart`).
- `soloud_backend.dart` — `SoloudBackend implements AudioBackend`, a thin
  `flutter_soloud` adapter: init engine (max voices 32, global limiter),
  music + SFX buses, SFX loaded in memory and music streamed
  (`LoadMode.disk`). Only volume/speed faders and buses (no per-sound
  filters, which web doesn't support); device stop/start for lifecycle.

### Game wiring

- `GameController(settings, {..., GameAudio audio = const SilentAudio()})`.
- `Mood get mood` — pure mapping, unit-tested:
  - overlay `endTrust` → `trust`, `endDont` → `exit`, `endTrue` → `truthEnd`;
  - stage 5 → `room`; 4 → `watching`; 3 → `broken`;
  - stage 2 after the lie → `silence` while `continuePrompt`, else `lie`;
  - otherwise `trust`.
- `_syncMusic()` calls `audio.mood(mood)`; called from `_syncRoom()`,
  `onContinue()` and `_end()`.
- Cue points in the controller: `_say` (by `LineKind`), typing in `tick`,
  walking steps in `tick`, natural glitch-burst start in `tick` (edge on
  `glitch.bursting`; `GlitchDirector` exposes whether the burst is heavy),
  `_transition` (start sound + `cover`; at reveal start `uncover` +
  `tearOpen`), stage-card typing, door / cabinet / key / crack / dial /
  unlock, pause / resume (+ `duck`), endings.
- Stage-card typing: `StageTransition` gets a `cardChars` getter used by both
  the overlay (replacing its inline calculation, same result) and the
  controller's tick sound.
- Screens:
  - `main.dart` creates `AudioDirector(SoloudBackend(), settings)` and wraps the app in `AudioScope`;
    `DontTrustTheGame` takes an optional `audio` (default `SilentAudio`), so
    existing widget tests are unchanged.
  - `MainMenuScreen` sets `trust`; `BootScreen` sets `silence` and plays boot
    cues from its existing timer; `GameScreen` passes the audio to the
    controller and on dispose un-ducks and sets `trust`.
  - `BlockButton` / `HudButton` play `click` on tap; the settings screen
    plays `click` for its cells/toggles (after applying the SFX value, so the
    click previews the new level).
- Web: add `<script src="assets/packages/flutter_soloud/web/init_soloud.js" defer></script>`
  to `web/index.html`.

### Asset pipeline

- `tool/audio/generate_audio.py` (numpy, scipy, soundfile; pinned in
  `tool/audio/requirements.txt`, installed in a git-ignored
  `tool/audio/.venv`). Deterministic (fixed seeds).
- Small synth toolkit: oscillators, ADSR, FM/additive bell (music box),
  detuned pad, filtered noise, biquad filters, Schroeder/Freeverb-style
  reverb, bitcrush/sample-hold, tape wobble; note sequences written as data.
- Loops are rendered with a tail and the tail is wrapped into the start, so
  reverb carries across the loop point with no click.
- Output: `assets/audio/music/*.ogg` (Vorbis, 44.1 kHz stereo, ~1–1.5 MB
  total) and `assets/audio/sfx/*.wav` (44.1 kHz mono 16-bit). Both folders
  declared in `pubspec.yaml`. Generated files are committed; building the
  game never needs Python.
- `assets/audio/README.md` states the audio is original and generated in
  this repo. The project README gets an *Audio* section (concept, how to
  regenerate).

## Testing

- **Unit:** `volumeGain` (mute, 0 dB at 10, monotonic); `Mood` mapping for
  every stage / lie state / ending.
- **Controller with a `RecordingAudio` fake:**
  - full playthrough: key cues fire at the right beats (door locked, lie
    sting + tape-stop, silence then `lie` on continue, transitions with
    cover/uncover, stage moods, endings);
  - typing ticks skip spaces and ok/lie/voice lines;
  - REDUCE GLITCH: no glitch SFX/hiccups, `fade` instead of tear/light;
  - pause/resume duck.
- **Assets:** every `Sfx` / `Mood` file exists on disk and its folder is
  declared in `pubspec.yaml`.
- **Settings:** tapping the first cell at 1 mutes (0).
- Existing tests keep passing unchanged (silent audio by default).
- **Manual:** `flutter run` on a device, play through all stages and the
  three endings, and check levels by ear.

## Out of scope

Voice acting / speech synthesis, 3D/positional audio, per-sound DSP filters,
background audio / media-session integration, new settings.
