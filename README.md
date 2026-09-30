# Don't Trust The Game

A mobile 2D psychological puzzle in an isometric room, built with Flutter + Flame
from a Claude Design handoff (`Dont Trust The Game.dc.html`).

```sh
flutter pub get
flutter run                              # menu → boot → stage 01
flutter run --dart-define=START_STAGE=3  # jump to a stage (1–4) for testing
flutter run --dart-define=CHARACTER=cloak # player design: pill (default) | cloak | block
flutter test
```

## Structure

| Path | What |
| --- | --- |
| `lib/room/` | The Flame world: 2:1 iso projection (`iso.dart`), the mutable `RoomScene`, and `RoomGame` — flat polygons, 3 tones per object, priority-sorted pieces, and the glitch layer (red ghost ±3px + offset horizontal slices). |
| `lib/game/game_controller.dart` | The story state machine (01 TRUST → 05 TRUTH, 3 endings) on a pause-aware clock: typing, walking (170ms/tile, BFS), scheduled beats and idle comments all freeze while paused. |
| `lib/audio/` | Audio: cue catalog (`Sfx`, `Mood`), the `GameAudio` interface, `AudioDirector` (crossfades, tape-stop, ducking, cooldowns, settings) and the flutter_soloud backend. |
| `lib/game/overlays.dart` | Flutter overlays over the `GameWidget`: HUD, terminal, pause, drawer puzzle, log, truth choice, endings. |
| `lib/screens/` | Main menu, boot/intro, gameplay, settings. |
| `lib/widgets/common.dart` | `DesignFrame` (lays out on the design's 360-wide canvas and scales to the device), bracket buttons, blinking cursor, scanlines. |

## Flow

1. **TRUST** — "MOVE RIGHT." → "OPEN THE DOOR." → "IT'S LOCKED."
2. **FIRST LIE** — "THE KEY IS IN THE DRAWER." The drawer puzzle says the code is 1-2-3-4; the real code (4·0·7·1) is scratched on the wall. The drawer is empty → "I LIED." → "DON'T GO THERE." (the key is there).
3. **UI GLITCH** — pause becomes `[ TRUST ME ]`, HUD swaps sides, MOVE → OBEY, room slices + red ghost.
4. **WATCHING** — back in room 01. The game comments on idling (7s), always going left, and pause count. A crack appears in the wall.
5. **TRUTH** — the secret room. Trust → loop to start; Don't trust → exit; Do nothing (or wait 12s) → true ending.

## Differences from the prototype

- The drawer puzzle and the `[ CONTINUE ] / [ LOG ]` dialogue step, shown as separate static screens in the design, are both part of stage 02 here.
- The scratched code sits left of the door, as `4·0·7·1`. In the prototype the door covered the "7".
- The secret-room wall lines are re-spaced and the left-wall lines wrapped, so they no longer overlap each other or the opening.
- IBM Plex Mono has no ▸ ▲ ▼ glyphs, so they are drawn as small triangles.
- Music and sound effects are original and generated in this repo (see
  **Audio**). Vibration is used for the lie and for flashes; screen shake
  applies to flashes.

## Glitch, transitions, character

- **Living glitch** (`lib/game/glitch.dart`): a `GlitchDirector` on the game clock
  fires short bursts whose frequency depends on the story. It is still in 01 and 05,
  rare after "I LIED." in 02 (the pause button flashes `[ TRUST ME ]` once in a
  while), steady in 04 and frequent in 03. During a burst the room slices and
  red ghost are re-rolled every 50ms, the HUD jitters, labels swap
  (`[ II ]`↔`[ TRUST ME ]`, `04 / I SEE YOU`, `I KNOW WHERE YOU'LL TAP`) and a
  few characters of the instruction are scrambled. Between bursts 03–04 look
  exactly like the design. Pausing freezes it.
- **REDUCE GLITCH** (Settings, off by default): no bursts (no flicker,
  jitter, label swaps or scrambling), and transitions become a plain fade
  with the same stage card. The steady 03–04 look from the design stays. It
  also switches on automatically when the OS "remove animations / reduce
  motion" accessibility setting is on. Unlike "LET THE GAME HELP YOU", the
  game never overrides it.
- **Stage transitions** (`lib/game/transition_overlay.dart`) replace the white
  flash. There are two kinds:
  - black bands tear shut for 02 → 03;
  - light floods out of the door (03 → 04) or the crack (04 → 05).

  Both hold on a typed stage card. The stage swaps while the screen is fully
  covered, and input and pause are locked meanwhile.
- **Character** (`lib/room/character.dart`) has 3 designs × 4 iso facings × idle
  (4 frames) + walk (8 frames: bob, squash, lean, alternating feet). It is played
  in-game from sprite sheets by `PlayerSheet`, faces where it walks, and idles
  when it stops. `docs/characters.png` compares the designs.

### Sprite sheets

`assets/images/sprites/player_<style>.png` + `player.json` (atlas: frame size,
anchor, rows = facings, idle/walk frame ranges and timing). Regenerate from the
painter with:

```sh
flutter test tool/generate_sprites.dart
```

Artists can replace the PNGs directly; the game reads frame counts and timing
from `player.json`, so a hand-drawn sheet with a different layout only needs the
JSON updated. Frames are drawn at 4× (128×192 px, feet at 64,168) and shown at
32×48 room units.

## Audio

**A lullaby that lies.** The game has one musical voice: a music-box tune
over a warm pad, friendly the way "I WILL HELP YOU." is. As trust breaks,
the *same song* decays instead of being swapped for other music:

| Moment | Music |
| --- | --- |
| Menu, 01 | The lullaby. Once per loop one note sags out of tune, the musical "don't". |
| 02, "I LIED." | Tape-stop: the song slows and pitch-dives to silence, and stays silent until `[ CONTINUE ]`. Then the same song returns sour, each phrase ending a semitone wrong. |
| 03 | Broken: bitcrushed fragments, stutters, dropouts over a dissonant drone. Glitch bursts make the music stumble. |
| 04 | Slower and lower, notes missing (it's listening), a soft pulse. |
| 05 | No music, only the room: "the game cannot control you if you stop listening". |
| Endings | TRUST cuts straight back to the lullaby. DON'T TRUST opens onto wind. TRUE: silence, then one pure chord, once. |

- **SFX:** 28 short sounds (UI clicks, typing ticks, steps, door, drawer,
  dial, key, crack, lie sting, glitches, transitions, pause).
  Rapid repeats are rate-limited.
- **REDUCE GLITCH:** no glitch sounds or music stumbles, and soft whooshes
  instead of the tear and light sounds.
- **Volume:** MUSIC and SFX are live (−3 dB per step). Tap the first cell
  again at 1 to mute.

All audio is original, synthesized by `tool/audio/generate_audio.py` from
oscillators and noise (no samples, fixed seeds). See
`assets/audio/README.md`. To change a sound, edit `tool/audio/sfx.py` or
`tool/audio/music.py` and regenerate:

```sh
python -m venv tool/audio/.venv
tool/audio/.venv/Scripts/pip install -r tool/audio/requirements.txt   # bin/ on macOS/Linux
tool/audio/.venv/Scripts/python tool/audio/generate_audio.py           # or: … generate_audio.py click trust
tool/audio/.venv/Scripts/python -m unittest discover -s tool/audio
```

In the app (`lib/audio/`), the game only sends cues (`play(Sfx)`,
`mood(Mood)`, `tapeStop()` …) to `GameAudio`. `AudioDirector` turns them
into crossfades, ducking and cooldowns, and `SoloudBackend` plays them with
[flutter_soloud](https://pub.dev/packages/flutter_soloud). Tests run
silent.

## App icon

`assets/icon/icon.png` (full icon: iOS, web, legacy Android) and
`assets/icon/icon_foreground.png` (Android adaptive foreground on `#0B0B0C`) are
rendered from SVG by `tool/render_icon.js`: the isometric room with its lit door and
a red glitch ghost. To regenerate:

```sh
node tool/render_icon.js            # needs playwright
dart run flutter_launcher_icons
git checkout ios/Runner.xcodeproj/project.pbxproj  # the tool wrongly edits a build flag there
```

## Splash screen

Plain `#0B0B0C` launch screen (same as the menu background) on Android (incl. the
Android 12+ splash API), iOS and web, generated by `flutter_native_splash`
(`dart run flutter_native_splash:create`). After regenerating, re-apply by hand:
Android `NormalTheme` `windowBackground` → `#0B0B0C` in the four `values*/styles.xml`
(otherwise a white frame shows between splash and Flutter), and the iOS
`LaunchScreen.storyboard` view background → dark.

Fonts: IBM Plex Mono and Instrument Serif (SIL OFL, `assets/fonts/OFL.txt`).
