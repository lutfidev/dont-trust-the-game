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
  /// failure, leaving the engine shut down.
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
/// remembered and started once it is ready. If the engine fails to start, the
/// game simply stays silent; an engine call that throws later costs only that
/// sound. While the app is hidden ([suspend]) the device is stopped and
/// nothing new plays; the game keeps running, so the mood it asks for
/// meanwhile starts on [resume].
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

  /// Silence between the fade-out and the true-ending chord.
  static const truthEndSilence = Duration(milliseconds: 1500);

  bool _ready = false, _covered = false, _ducked = false, _suspended = false;
  bool _assist = true;

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
    if (_suspended) {
      // Hidden while loading: the engine just started its device.
      await _device(_backend.suspend);
    } else {
      _apply();
    }
  }

  /// The app is hidden: stop the device, play nothing new.
  Future<void> suspend() async {
    if (_suspended) return;
    _suspended = true;
    await _device(_backend.suspend);
  }

  /// The app is back: restart the device and catch up with the mood.
  Future<void> resume() async {
    if (!_suspended) return;
    _suspended = false;
    await _device(_backend.resume);
    _apply();
  }

  Future<void> _device(Future<void> Function() op) async {
    if (!_ready) return;
    try {
      await op();
    } catch (e) {
      debugPrint('Audio device: $e');
    }
  }

  /// Makes one engine call. If it throws, the error is logged and the call
  /// skipped (null): a misbehaving engine may cost a sound, never the game.
  T? _engine<T>(T Function() call) {
    try {
      return call();
    } catch (e) {
      debugPrint('Audio: $e');
      return null;
    }
  }

  @override
  void play(Sfx sfx, {double rate = 1}) {
    if (!_ready || _suspended || _settings.sfx == 0) return;
    final now = _now(), last = _last[sfx];
    if (last != null && now - last < sfx.cooldownMs) return;
    _last[sfx] = now;
    final r = rate * (1 + (_rnd.nextDouble() * 2 - 1) * sfx.vary);
    _engine(() => _backend.playSfx(sfx, rate: r));
  }

  @override
  void mood(Mood mood, {bool cut = false}) {
    _want = mood;
    _apply(cut: cut);
  }

  void _apply({bool cut = false}) {
    if (!_ready || _covered || _suspended || _want == _playing) return;
    _stopVoice(cut ? Duration.zero : fadeOut);
    final m = _playing = _want;
    final gen = ++_generation;
    switch (m) {
      case Mood.silence:
        break;
      case Mood.truthEnd:
        _schedule(fadeOut + truthEndSilence, () {
          if (gen != _generation) return;
          if (_suspended) {
            _playing = Mood.silence; // start it on resume instead
          } else {
            _voice = _engine(() => _backend.startMusic(m, volume: 1));
          }
        });
      default:
        final v = _voice = _engine(() => _backend.startMusic(m, volume: cut ? 1 : 0));
        if (v != null && !cut) {
          _engine(() => _backend.fadeVolume(v, 1, Duration(milliseconds: m.fadeInMs)));
        }
    }
  }

  void _stopVoice(Duration fade) {
    final v = _voice;
    if (v == null) return;
    _voice = null;
    if (fade > Duration.zero) _engine(() => _backend.fadeVolume(v, 0, fade));
    _engine(() => _backend.stopAfter(v, fade));
  }

  @override
  void tapeStop() {
    final v = _voice;
    if (v == null) return;
    _voice = null;
    _generation++;
    _playing = Mood.silence;
    _engine(() => _backend.fadeSpeed(v, .05, const Duration(milliseconds: 900)));
    _engine(() => _backend.fadeVolume(v, 0, const Duration(milliseconds: 1000)));
    _engine(() => _backend.stopAfter(v, const Duration(milliseconds: 1000)));
  }

  @override
  void hiccup({required bool heavy}) {
    final v = _voice;
    if (v == null || _playing == Mood.truthEnd) return;
    _engine(() => _backend.setSpeed(v, heavy ? .88 : .95));
    _engine(() => _backend.fadeSpeed(v, 1, const Duration(milliseconds: 180)));
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
    if (_ready) _engine(() => _backend.fadeMusicBus(_musicBus, duckTime));
  }

  double get _musicBus => volumeGain(_settings.music) * (_ducked ? duckLevel : 1);

  void _applyBus() => _engine(() =>
      _backend.setBusVolumes(music: _musicBus, sfx: volumeGain(_settings.sfx)));

  void _onSettings() {
    _applyBus();
    if (_settings.assist && !_assist) play(Sfx.deny); // "NO."
    _assist = _settings.assist;
  }
}
