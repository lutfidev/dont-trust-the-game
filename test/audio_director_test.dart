import 'dart:math' as math;

import 'package:dont_trust_the_game/audio/audio_director.dart';
import 'package:dont_trust_the_game/audio/cues.dart';
import 'package:dont_trust_the_game/settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsStore settings;
  late FakeBackend fake;
  late List<(Duration, VoidCallback)> scheduled;
  var clock = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsStore.load();
    fake = FakeBackend();
    scheduled = [];
    clock = 0;
  });

  AudioDirector director() => AudioDirector(fake, settings,
      random: math.Random(0),
      now: () => clock,
      schedule: (d, run) => scheduled.add((d, run)));

  Future<AudioDirector> ready([Mood mood = Mood.trust]) async {
    final d = director()..mood(mood);
    await d.start();
    fake.log.clear();
    return d;
  }

  test('nothing plays before the engine is ready; then the wanted mood starts', () async {
    final d = director()
      ..mood(Mood.trust)
      ..play(Sfx.click);
    expect(fake.log, isEmpty);
    await d.start();
    expect(d.ready, isTrue);
    expect(fake.log, [
      'init',
      'bus music 0.25 sfx 0.50', // defaults MUSIC 6, SFX 8
      'start trust 0.00 #1',
      'fade #1 1.00 2500',
    ]);
  });

  test('an engine that fails to start leaves the game silent', () async {
    fake.failInit = true;
    final d = director();
    await d.start();
    d
      ..mood(Mood.trust)
      ..play(Sfx.click)
      ..tapeStop()
      ..hiccup(heavy: true)
      ..cover(const Duration(milliseconds: 380))
      ..uncover()
      ..duck(true);
    await d.suspend();
    expect(d.ready, isFalse);
    expect(fake.log, isEmpty);
  });

  test('an engine call that throws costs its sound, never the game', () async {
    final d = await ready();
    fake.failCalls = true;
    d
      ..play(Sfx.click)
      ..hiccup(heavy: true)
      ..mood(Mood.lie) // the old voice can't be stopped, the new one can't start
      ..tapeStop()
      ..cover(const Duration(milliseconds: 380))
      ..uncover()
      ..duck(true);
    settings.setMusic(3);
    await d.suspend();
    await d.resume();
    expect(fake.log, isEmpty);

    fake.failCalls = false; // once the engine answers again, music goes on
    d.mood(Mood.broken);
    expect(fake.log, ['start broken 0.00 #2', 'fade #2 1.00 400']);
  });

  test('moods crossfade, repeats are no-ops, cut is instant', () async {
    final d = await ready();
    d.mood(Mood.trust);
    expect(fake.log, isEmpty);
    d.mood(Mood.lie);
    expect(fake.log, ['fade #1 0.00 1200', 'stop #1 1200', 'start lie 0.00 #2', 'fade #2 1.00 1800']);
    fake.log.clear();
    d.mood(Mood.trust, cut: true);
    expect(fake.log, ['stop #2 0', 'start trust 1.00 #3']);
  });

  test('the tape-stop halts the music; the silence that follows is a no-op', () async {
    final d = await ready();
    d.tapeStop();
    expect(fake.log, ['fadespeed #1 0.05 900', 'fade #1 0.00 1000', 'stop #1 1000']);
    fake.log.clear();
    d
      ..mood(Mood.silence)
      ..hiccup(heavy: true); // nothing playing to stumble
    expect(fake.log, isEmpty);
    d.mood(Mood.lie);
    expect(fake.log, ['start lie 0.00 #2', 'fade #2 1.00 1800']);
  });

  test('a glitch hiccup jolts the play speed and eases back', () async {
    final d = await ready(Mood.broken);
    d.hiccup(heavy: true);
    d.hiccup(heavy: false);
    expect(fake.log, [
      'speed #1 0.88',
      'fadespeed #1 1.00 180',
      'speed #1 0.95',
      'fadespeed #1 1.00 180',
    ]);
  });

  test('cover holds mood changes until uncover', () async {
    final d = await ready();
    d.cover(const Duration(milliseconds: 380));
    expect(fake.log, ['fade #1 0.00 380', 'stop #1 380']);
    fake.log.clear();
    d.mood(Mood.broken);
    expect(fake.log, isEmpty);
    d.uncover();
    expect(fake.log, ['start broken 0.00 #2', 'fade #2 1.00 400']);
  });

  test('leaving for the menu mid-transition still starts the lullaby', () async {
    final d = await ready(Mood.broken);
    d
      ..cover(const Duration(milliseconds: 450))
      ..mood(Mood.watching) // stage swapped under cover
      ..mood(Mood.trust) // back to the menu
      ..uncover();
    expect(fake.log.last, 'fade #2 1.00 2500');
    expect(fake.log, contains('start trust 0.00 #2'));
  });

  test('the true ending fades out, waits, then plays its chord once', () async {
    final d = await ready(Mood.room);
    d.mood(Mood.truthEnd);
    expect(fake.log, ['fade #1 0.00 1200', 'stop #1 1200']);
    // ~1.5 s of real silence after the 1.2 s fade-out, then the chord.
    expect(scheduled.single.$1, const Duration(milliseconds: 2700));
    scheduled.single.$2();
    expect(fake.log.last, 'start truthEnd 1.00 #2');
  });

  test('a stale true-ending start is ignored after the mood moved on', () async {
    final d = await ready(Mood.room);
    d
      ..mood(Mood.truthEnd)
      ..mood(Mood.trust);
    scheduled.single.$2();
    expect(fake.log.where((l) => l.startsWith('start truthEnd')), isEmpty);
  });

  test('cooldowns drop fast repeats; vary stays in range', () async {
    final d = await ready();
    d.play(Sfx.type);
    clock = 10;
    d.play(Sfx.type); // dropped: 45ms cooldown
    clock = 50;
    d.play(Sfx.type);
    final plays = fake.log.where((l) => l.startsWith('sfx type')).toList();
    expect(plays, hasLength(2));
    for (final p in plays) {
      expect(double.parse(p.split(' ').last), inInclusiveRange(.92, 1.08));
    }
    d.play(Sfx.step, rate: 1.04);
    expect(fake.log.last, 'sfx step 1.04'); // no vary on steps
  });

  test('settings drive the buses; pause ducks; zero is silent', () async {
    final d = await ready();
    settings.setMusic(10);
    expect(fake.log.last, 'bus music 1.00 sfx 0.50');
    d.duck(true);
    expect(fake.log.last, 'busfade 0.30 250');
    d.duck(true);
    expect(fake.log.last, 'busfade 0.30 250', reason: 'no repeat');
    settings.setMusic(0);
    expect(fake.log.last, 'bus music 0.00 sfx 0.50');
    settings.setSfx(0);
    fake.log.clear();
    d.play(Sfx.click);
    expect(fake.log, isEmpty);
  });

  test('"LET THE GAME HELP YOU" switching itself back on says no', () async {
    await ready();
    settings.toggleAssist();
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(fake.log, anyElement(startsWith('sfx deny')));
  });

  test('suspend and resume reach the engine only once it is running', () async {
    final d = director();
    await d.suspend();
    expect(fake.log, isEmpty);
    await d.start();
    await d.suspend();
    await d.resume();
    expect(fake.log.sublist(fake.log.length - 2), ['suspend', 'resume']);
  });

  test('spamming a button does not stack its sound', () async {
    final d = await ready();
    for (final s in [Sfx.wrong, Sfx.wrongLied, Sfx.doorLocked, Sfx.voice, Sfx.pause, Sfx.resume]) {
      clock += 5000;
      d.play(s);
      clock += 100;
      d.play(s); // a second tap 100ms later
      expect(fake.log.where((l) => l.startsWith('sfx ${s.name} ')), hasLength(1), reason: s.name);
    }
  });

  test('while the app is hidden, cues stay silent and the mood waits for resume', () async {
    final d = await ready();
    await d.suspend();
    expect(fake.log, ['suspend']);
    fake.log.clear();
    d
      ..play(Sfx.step)
      ..mood(Mood.lie);
    expect(fake.log, isEmpty);
    await d.resume();
    expect(fake.log, [
      'resume',
      'fade #1 0.00 1200',
      'stop #1 1200',
      'start lie 0.00 #2',
      'fade #2 1.00 1800',
    ]);
  });

  test('the true-ending chord waits until the app is back', () async {
    final d = await ready(Mood.room);
    d.mood(Mood.truthEnd);
    await d.suspend();
    scheduled.single.$2(); // the delay ends while hidden
    expect(fake.log.where((l) => l.startsWith('start truthEnd')), isEmpty);
    await d.resume();
    scheduled.last.$2();
    expect(fake.log.last, 'start truthEnd 1.00 #2');
  });

  test('hidden while still loading: the engine is silenced as soon as it is up', () async {
    final d = director()..mood(Mood.trust);
    await d.suspend();
    await d.start();
    expect(fake.log, ['init', 'bus music 0.25 sfx 0.50', 'suspend']);
    await d.resume();
    expect(fake.log.sublist(3), ['resume', 'start trust 0.00 #1', 'fade #1 1.00 2500']);
  });
}
