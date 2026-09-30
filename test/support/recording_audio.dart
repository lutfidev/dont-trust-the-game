import 'package:dont_trust_the_game/audio/cues.dart';
import 'package:dont_trust_the_game/audio/game_audio.dart';

/// Records every cue the game sends. [moods] only lists changes.
class RecordingAudio implements GameAudio {
  final calls = <String>[];
  final played = <Sfx>[];
  final moods = <Mood>[];
  Mood? _current;

  int count(Sfx s) => played.where((p) => p == s).length;

  /// Forgets what was recorded, but remembers the current mood.
  void clear() {
    calls.clear();
    played.clear();
    moods.clear();
  }

  @override
  void play(Sfx sfx, {double rate = 1}) {
    played.add(sfx);
    calls.add('play ${sfx.name}');
  }

  @override
  void mood(Mood mood, {bool cut = false}) {
    calls.add('mood ${mood.name}${cut ? ' cut' : ''}');
    if (mood != _current) moods.add(mood);
    _current = mood;
  }

  @override
  void tapeStop() => calls.add('tapeStop');
  @override
  void hiccup({required bool heavy}) => calls.add('hiccup ${heavy ? 'heavy' : 'light'}');
  @override
  void cover(Duration fade) => calls.add('cover ${fade.inMilliseconds}');
  @override
  void uncover() => calls.add('uncover');
  @override
  void duck(bool on) => calls.add('duck $on');
}
