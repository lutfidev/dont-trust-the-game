import 'package:flutter/widgets.dart';

import 'cues.dart';

/// What the game asks of its audio. The game only says what happened;
/// implementations decide how it sounds.
abstract interface class GameAudio {
  /// Plays a one-shot sound; [rate] also shifts its pitch.
  void play(Sfx sfx, {double rate = 1});

  /// Moves the music to [mood]. [cut] switches instantly instead of
  /// crossfading. Asking for the current mood does nothing.
  void mood(Mood mood, {bool cut = false});

  /// "I LIED.": the music slows to a halt, its pitch falling with it.
  void tapeStop();

  /// A glitch burst: the music stumbles for a moment.
  void hiccup({required bool heavy});

  /// A stage transition covers the screen: the music fades out over [fade]
  /// and mood changes wait for [uncover].
  void cover(Duration fade);

  /// The screen is being revealed: start the mood asked for meanwhile.
  void uncover();

  /// The pause menu: the music ducks under it.
  void duck(bool on);

  /// Clears transient audio state before a new playthrough starts.
  void reset();
}

/// No sound at all: the default everywhere, so tests need no audio engine.
class SilentAudio implements GameAudio {
  const SilentAudio();

  @override
  void play(Sfx sfx, {double rate = 1}) {}
  @override
  void mood(Mood mood, {bool cut = false}) {}
  @override
  void tapeStop() {}
  @override
  void hiccup({required bool heavy}) {}
  @override
  void cover(Duration fade) {}
  @override
  void uncover() {}
  @override
  void duck(bool on) {}
  @override
  void reset() {}
}

/// Makes the app's [GameAudio] available to every screen and button.
class AudioScope extends InheritedWidget {
  const AudioScope({super.key, required this.audio, required super.child});
  final GameAudio audio;

  /// The app's audio, or silence when there is none (e.g. widget tests).
  /// Safe to call from `initState`: it doesn't subscribe to changes.
  static GameAudio of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AudioScope>()?.audio ??
      const SilentAudio();

  @override
  bool updateShouldNotify(AudioScope oldWidget) => audio != oldWidget.audio;
}
