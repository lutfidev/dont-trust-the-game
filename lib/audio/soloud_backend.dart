import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'audio_director.dart';
import 'cues.dart';

/// [AudioBackend] on flutter_soloud. Two mixing buses (music, SFX); SFX are
/// decoded into memory for instant playback, music stays compressed in memory
/// and is decoded as it plays. Only volume/speed faders are used, which work
/// on every platform.
class SoloudBackend implements AudioBackend {
  final _soloud = SoLoud.instance;
  late final Bus _music, _sfx;
  final _sfxSources = <Sfx, AudioSource>{};
  final _musicSources = <Mood, AudioSource>{};
  final _voices = <int, SoundHandle>{};
  var _ids = 0;

  @override
  Future<void> init() async {
    // Every file is fetched at once, while the engine starts: on the web each
    // one is a request of its own, and one after another they take seconds.
    final moods = [for (final m in Mood.values) if (m.asset != null) m];
    final sfxBytes = Future.wait([for (final s in Sfx.values) _bytes(s.asset)]);
    final musicBytes = Future.wait([for (final m in moods) _bytes(m.asset!)]);
    // Not awaited until the engine is up, so a failure meanwhile must not be
    // reported as unhandled; the awaits below still get it.
    sfxBytes.ignore();
    musicBytes.ignore();

    await _soloud.init();
    try {
      _soloud
        ..setMaxActiveVoiceCount(32)
        ..filters.limiterFilter.activate(); // stacked sounds never clip
      _music = _soloud.createMixingBus(name: 'music')..playOnEngine();
      _sfx = _soloud.createMixingBus(name: 'sfx')..playOnEngine();
      // The engine takes them one at a time.
      for (final (i, bytes) in (await sfxBytes).indexed) {
        final s = Sfx.values[i];
        _sfxSources[s] = await _soloud.loadMem(s.asset, bytes);
      }
      // LoadMode.disk keeps the compressed bytes and decodes as it plays.
      // (loadAsset would stream from a temporary file instead, which the OS
      // may clear while the game is running.)
      for (final (i, bytes) in (await musicBytes).indexed) {
        final m = moods[i];
        _musicSources[m] = await _soloud.loadMem(m.asset!, bytes, mode: LoadMode.disk);
      }
    } catch (_) {
      // The game will stay silent: don't leave the audio device running.
      await _soloud
          .deinitAsync()
          .catchError((Object e) => debugPrint('Audio shutdown: $e'));
      rethrow;
    }
  }

  static Future<Uint8List> _bytes(String asset) async {
    final data = await rootBundle.load(asset);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  @override
  void setBusVolumes({required double music, required double sfx}) {
    _soloud
      ..setVolume(_music.soundHandle!, music)
      ..setVolume(_sfx.soundHandle!, sfx);
  }

  @override
  void fadeMusicBus(double to, Duration time) =>
      _soloud.fadeVolume(_music.soundHandle!, to, time);

  @override
  void playSfx(Sfx sfx, {required double rate}) {
    final h = _sfx.play(_sfxSources[sfx]!, paused: true);
    if (!_soloud.getIsValidVoiceHandle(h)) return; // voice limit reached
    _soloud
      ..setRelativePlaySpeed(h, rate)
      ..setPause(h, false);
  }

  @override
  int startMusic(Mood mood, {required double volume}) {
    final h = _music.play(_musicSources[mood]!, paused: true, looping: mood.loop);
    if (_soloud.getIsValidVoiceHandle(h)) {
      // A recycled handle can inherit an old fade: reset before unpausing.
      _soloud
        ..setVolume(h, volume)
        ..setRelativePlaySpeed(h, 1)
        ..setPause(h, false);
    }
    _voices[++_ids] = h;
    return _ids;
  }

  SoundHandle? _live(int voice) {
    final h = _voices[voice];
    return h != null && _soloud.getIsValidVoiceHandle(h) ? h : null;
  }

  @override
  void fadeVolume(int voice, double to, Duration time) {
    final h = _live(voice);
    if (h != null) _soloud.fadeVolume(h, to, time);
  }

  @override
  void setSpeed(int voice, double speed) {
    final h = _live(voice);
    if (h != null) _soloud.setRelativePlaySpeed(h, speed);
  }

  @override
  void fadeSpeed(int voice, double to, Duration time) {
    final h = _live(voice);
    if (h != null) _soloud.fadeRelativePlaySpeed(h, to, time);
  }

  @override
  void stopAfter(int voice, Duration time) {
    final h = _live(voice);
    _voices.remove(voice);
    if (h == null) return;
    if (time == Duration.zero) {
      // Asynchronous, so the director's guard can't catch its errors.
      unawaited(_soloud.stop(h).catchError((Object e) => debugPrint('Audio: $e')));
    } else {
      _soloud.scheduleStop(h, time);
    }
  }

  /// Forced: without it this is a no-op while any voice plays, and the two
  /// buses always do. The director plays nothing new until [resume].
  @override
  Future<void> suspend() => _soloud.stopAudioDevice(force: true);

  @override
  Future<void> resume() => _soloud.startAudioDevice();
}
