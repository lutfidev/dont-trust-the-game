import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'audio_director.dart';
import 'cues.dart';

/// [AudioBackend] on flutter_soloud. Two mixing buses (music, SFX); SFX are
/// decoded into memory for instant playback, music is streamed from disk.
/// Only volume/speed faders are used, which work on every platform.
class SoloudBackend implements AudioBackend {
  final _soloud = SoLoud.instance;
  late final Bus _music, _sfx;
  final _sfxSources = <Sfx, AudioSource>{};
  final _musicSources = <Mood, AudioSource>{};
  final _voices = <int, SoundHandle>{};
  var _ids = 0;

  @override
  Future<void> init() async {
    await _soloud.init();
    _soloud
      ..setMaxActiveVoiceCount(32)
      ..filters.limiterFilter.activate(); // stacked sounds never clip
    _music = _soloud.createMixingBus(name: 'music')..playOnEngine();
    _sfx = _soloud.createMixingBus(name: 'sfx')..playOnEngine();
    for (final s in Sfx.values) {
      _sfxSources[s] = await _soloud.loadAsset(s.asset,
          mode: kIsWeb ? LoadMode.disk : LoadMode.memory);
    }
    for (final m in Mood.values) {
      final asset = m.asset;
      if (asset != null) {
        _musicSources[m] = await _soloud.loadAsset(asset, mode: LoadMode.disk);
      }
    }
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
      unawaited(_soloud.stop(h));
    } else {
      _soloud.scheduleStop(h, time);
    }
  }

  @override
  Future<void> suspend() => _soloud.stopAudioDevice();

  @override
  Future<void> resume() => _soloud.startAudioDevice();
}
