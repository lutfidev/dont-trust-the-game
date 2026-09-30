import 'package:dont_trust_the_game/audio/audio_director.dart';
import 'package:dont_trust_the_game/audio/cues.dart';

/// Logs engine calls as short strings, e.g. `fade #1 1.00 2500`.
class FakeBackend implements AudioBackend {
  final log = <String>[];
  bool failInit = false;

  /// Every call after [init] throws, like an engine that went away.
  bool failCalls = false;
  int _ids = 0;

  String _f(double v) => v.toStringAsFixed(2);

  void _call(String entry) {
    if (failCalls) throw StateError('engine gone: $entry');
    log.add(entry);
  }

  @override
  Future<void> init() async {
    if (failInit) throw Exception('no output device');
    log.add('init');
  }

  @override
  void setBusVolumes({required double music, required double sfx}) =>
      _call('bus music ${_f(music)} sfx ${_f(sfx)}');
  @override
  void fadeMusicBus(double to, Duration time) =>
      _call('busfade ${_f(to)} ${time.inMilliseconds}');
  @override
  void playSfx(Sfx sfx, {required double rate}) => _call('sfx ${sfx.name} ${_f(rate)}');
  @override
  int startMusic(Mood mood, {required double volume}) {
    _call('start ${mood.name} ${_f(volume)} #${_ids + 1}');
    return ++_ids;
  }

  @override
  void fadeVolume(int voice, double to, Duration time) =>
      _call('fade #$voice ${_f(to)} ${time.inMilliseconds}');
  @override
  void setSpeed(int voice, double speed) => _call('speed #$voice ${_f(speed)}');
  @override
  void fadeSpeed(int voice, double to, Duration time) =>
      _call('fadespeed #$voice ${_f(to)} ${time.inMilliseconds}');
  @override
  void stopAfter(int voice, Duration time) => _call('stop #$voice ${time.inMilliseconds}');
  @override
  Future<void> suspend() async => _call('suspend');
  @override
  Future<void> resume() async => _call('resume');
}
