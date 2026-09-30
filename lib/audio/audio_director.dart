import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../settings.dart';
import 'cues.dart';
import 'game_audio.dart';

/// The engine operations [AudioDirector] needs. Music voices are ids handed
/// out by [startMusic].
abstract interface class AudioBackend {
  /// Starts the engine and loads every [Sfx] and [Mood] asset. Throws on
  /// failure.
  Future<void> init();
  void setBusVolumes({required double music, required double sfx});
  void fadeMusicBus(double to, Duration time);
  void playSfx(Sfx sfx, {required double rate});
  int startMusic(Mood mood, {required double volume});
  void fadeVolume(int voice, double to, Duration time);
  void setSpeed(int voice, double speed);
  void fadeSpeed(int voice, double to, Duration time);

  /// Stops [voice] after [time] (right away for [Duration.zero]).
  void stopAfter(int voice, Duration time);
  Future<void> suspend();
  Future<void> resume();
}

typedef Schedule = void Function(Duration delay, VoidCallback run);

/// Turns the game's cues into engine calls: crossfades, the tape-stop,
/// hiccups, ducking, cooldowns and the MUSIC / SFX settings.
///
/// Until [start] succeeds nothing is sent to the engine; the wanted mood is
/// remembered and started once it is ready. If the engine fails, the game
/// simply stays silent.
class AudioDirector implements GameAudio {
  AudioDirector(this._backend, this._settings,
      {math.Random? random, int Function()? now, Schedule? schedule})
      : _rnd = random ?? math.Random(),
        _now = now ?? _stopwatch(),
        _schedule = schedule ?? ((d, run) => Timer(d, run));

  final AudioBackend _backend;
  final SettingsStore _settings;
  final math.Random _rnd;
  final int Function() _now;
  final Schedule _schedule;

  static const fadeOut = Duration(milliseconds: 1200);
  static const duckLevel = .3;
  static const duckTime = Duration(milliseconds: 250);
  static const truthEndDelay = Duration(milliseconds: 1500);

  bool _ready = false, _covered = false, _ducked = false, _assist = true;

  /// The mood the game asked for, and the one actually sounding.
  Mood _want = Mood.silence, _playing = Mood.silence;
  int? _voice;

  /// Bumped whenever the music changes, so a delayed start can tell it's stale.
  int _generation = 0;
  final _last = <Sfx, int>{};

  bool get ready => _ready;

  static int Function() _stopwatch() {
    final sw = Stopwatch()..start();
    return () => sw.elapsedMilliseconds;
  }

  Future<void> start() async {
    try {
      await _backend.init();
    } catch (e) {
      debugPrint('Audio disabled: $e');
      return;
    }
    _ready = true;
    _assist = _settings.assist;
    _settings.addListener(_onSettings);
    _applyBus();
    _apply();
  }

  Future<void> suspend() => _device(_backend.suspend);
  Future<void> resume() => _device(_backend.resume);

  Future<void> _device(Future<void> Function() op) async {
    if (!_ready) return;
    try {
      await op();
    } catch (e) {
      debugPrint('Audio device: $e');
    }
  }

  @override
  void play(Sfx sfx, {double rate = 1}) {
    if (!_ready || _settings.sfx == 0) return;
    final now = _now(), last = _last[sfx];
    if (last != null && now - last < sfx.cooldownMs) return;
    _last[sfx] = now;
    _backend.playSfx(sfx, rate: rate * (1 + (_rnd.nextDouble() * 2 - 1) * sfx.vary));
  }

  @override
  void mood(Mood mood, {bool cut = false}) {
    _want = mood;
    _apply(cut: cut);
  }

  void _apply({bool cut = false}) {
    if (!_ready || _covered || _want == _playing) return;
    _stopVoice(cut ? Duration.zero : fadeOut);
    final m = _playing = _want;
    final gen = ++_generation;
    switch (m) {
      case Mood.silence:
        break;
      case Mood.truthEnd:
        _schedule(truthEndDelay, () {
          if (gen == _generation) _voice = _backend.startMusic(m, volume: 1);
        });
      default:
        final v = _voice = _backend.startMusic(m, volume: cut ? 1 : 0);
        if (!cut) _backend.fadeVolume(v, 1, Duration(milliseconds: m.fadeInMs));
    }
  }

  void _stopVoice(Duration fade) {
    final v = _voice;
    if (v == null) return;
    _voice = null;
    if (fade > Duration.zero) _backend.fadeVolume(v, 0, fade);
    _backend.stopAfter(v, fade);
  }

  @override
  void tapeStop() {
    final v = _voice;
    if (v == null) return;
    _voice = null;
    _generation++;
    _playing = Mood.silence;
    _backend
      ..fadeSpeed(v, .05, const Duration(milliseconds: 900))
      ..fadeVolume(v, 0, const Duration(milliseconds: 1000))
      ..stopAfter(v, const Duration(milliseconds: 1000));
  }

  @override
  void hiccup({required bool heavy}) {
    final v = _voice;
    if (v == null || _playing == Mood.truthEnd) return;
    _backend
      ..setSpeed(v, heavy ? .88 : .95)
      ..fadeSpeed(v, 1, const Duration(milliseconds: 180));
  }

  @override
  void cover(Duration fade) {
    _covered = true;
    if (!_ready) return;
    _stopVoice(fade);
    _generation++;
    _playing = Mood.silence;
  }

  @override
  void uncover() {
    _covered = false;
    _apply();
  }

  @override
  void duck(bool on) {
    if (_ducked == on) return;
    _ducked = on;
    if (_ready) _backend.fadeMusicBus(_musicBus, duckTime);
  }

  double get _musicBus => volumeGain(_settings.music) * (_ducked ? duckLevel : 1);

  void _applyBus() =>
      _backend.setBusVolumes(music: _musicBus, sfx: volumeGain(_settings.sfx));

  void _onSettings() {
    _applyBus();
    if (_settings.assist && !_assist) play(Sfx.deny); // "NO."
    _assist = _settings.assist;
  }
}
