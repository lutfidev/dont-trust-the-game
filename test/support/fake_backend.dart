import 'package:dont_trust_the_game/audio/audio_director.dart';
import 'package:dont_trust_the_game/audio/cues.dart';

/// Logs engine calls as short strings, e.g. `fade #1 1.00 2500`.
class FakeBackend implements AudioBackend {
  final log = <String>[];
  bool failInit = false;
  int _ids = 0;

  String _f(double v) => v.toStringAsFixed(2);

  @override
  Future<void> init() async {
    if (failInit) throw Exception('no output device');
    log.add('init');
  }

  @override
  void setBusVolumes({required double music, required double sfx}) =>
      log.add('bus music ${_f(music)} sfx ${_f(sfx)}');
  @override
  void fadeMusicBus(double to, Duration time) =>
      log.add('busfade ${_f(to)} ${time.inMilliseconds}');
  @override
  void playSfx(Sfx sfx, {required double rate}) => log.add('sfx ${sfx.name} ${_f(rate)}');
  @override
  int startMusic(Mood mood, {required double volume}) {
    log.add('start ${mood.name} ${_f(volume)} #${++_ids}');
    return _ids;
  }

  @override
  void fadeVolume(int voice, double to, Duration time) =>
      log.add('fade #$voice ${_f(to)} ${time.inMilliseconds}');
  @override
  void setSpeed(int voice, double speed) => log.add('speed #$voice ${_f(speed)}');
  @override
  void fadeSpeed(int voice, double to, Duration time) =>
      log.add('fadespeed #$voice ${_f(to)} ${time.inMilliseconds}');
  @override
  void stopAfter(int voice, Duration time) => log.add('stop #$voice ${time.inMilliseconds}');
  @override
  Future<void> suspend() async => log.add('suspend');
  @override
  Future<void> resume() async => log.add('resume');
}
