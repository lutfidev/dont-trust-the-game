import 'dart:math' as math;

import 'package:dont_trust_the_game/audio/cues.dart';
import 'package:dont_trust_the_game/game/game_controller.dart';
import 'package:dont_trust_the_game/room/room_scene.dart';
import 'package:dont_trust_the_game/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/recording_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsStore settings;
  late RecordingAudio a;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'vibration': false});
    settings = await SettingsStore.load();
    a = RecordingAudio();
  });

  void run(GameController g, int ms) {
    for (var t = 0; t < ms; t += 16) {
      g.tick(16);
    }
  }

  void findEchoes(GameController g) {
    for (final tile in GameController.echoTiles) {
      g.onTile(tile);
      run(g, 2500);
    }
  }

  void solveRoute(GameController g) {
    for (final tile in g.routeTargets) {
      final steps = GameController.path(
        g.scene.player!,
        tile,
        obstacles: g.scene.obstacles,
      )!.length;
      g.onTile(tile);
      run(g, steps * GameController.walkStepMs + 80);
    }
  }

  void reachFinalStage(GameController g) {
    if (g.stage == 5) {
      g.onCrack();
      run(g, 2000);
    }
    while (g.stage < 15) {
      solveRoute(g);
      g.onCrack();
      run(g, 2000);
    }
    solveRoute(g);
    run(g, 1000);
  }

  test('each stage has its music', () {
    for (final (stage, mood) in [
      (1, Mood.trust),
      (2, Mood.trust),
      (3, Mood.broken),
      (4, Mood.watching),
      (5, Mood.room),
      (6, Mood.broken),
      (9, Mood.watching),
      (12, Mood.broken),
      (15, Mood.broken),
    ]) {
      expect(
        GameController(settings, startStage: stage).mood,
        mood,
        reason: 'stage $stage',
      );
    }
  });

  test('the story plays its cues in order', () {
    final g = GameController(settings, random: math.Random(1), audio: a);
    expect(a.moods, [Mood.trust]);

    g.onTile(const Tile(4, 0));
    run(g, 3000);
    g.onDoor();
    run(g, 2000);
    expect(a.played, contains(Sfx.doorLocked));
    expect(g.stage, 2);

    // The puzzle.
    g.onCabinet();
    run(g, 2000);
    g.dials = [1, 2, 3, 4];
    g.unlock();
    expect(a.played.last, Sfx.wrongLied);
    g.dials = [...GameController.realCode];
    g.unlock();
    expect(a.played.last, Sfx.unlock);
    run(g, 3000);
    expect(a.played, containsAll([Sfx.drawerOpen, Sfx.lie]));
    expect(a.calls, contains('tapeStop'));

    // Silence while "I LIED." waits for CONTINUE; the lie version after.
    expect(g.mood, Mood.silence);
    expect(a.moods.last, Mood.silence);
    g.onContinue();
    expect(a.moods.last, Mood.lie);

    // Disobey → the tear into 03: cover, swap, then uncover.
    a.clear();
    g.onTile(const Tile(5, 5));
    run(g, 4000);
    expect(g.stage, 3);
    expect(a.played, containsAll([Sfx.key, Sfx.tear, Sfx.tearOpen]));
    final cover = a.calls.indexOf('cover 380');
    final broken = a.calls.indexOf('mood broken');
    final uncover = a.calls.indexOf('uncover');
    expect(cover, greaterThanOrEqualTo(0));
    expect(cover, lessThan(broken));
    expect(broken, lessThan(uncover));

    // 03 → 04 through the door.
    g.onDoor();
    run(g, 2000);
    expect(a.played, contains(Sfx.doorOpen));
    g.onDoor();
    run(g, 3000);
    expect(g.stage, 4);
    expect(a.moods.last, Mood.watching);
    expect(a.played, contains(Sfx.light));
    run(g, GameController.idleCommentMs + 500);
    expect(a.played, contains(Sfx.voice)); // "Why are you not moving?"

    // 04 → 05 reaches Truth, but the game does not end there.
    findEchoes(g);
    g.onCrack();
    run(g, 5000);
    expect(a.played, contains(Sfx.crack));
    expect(g.stage, 5);
    expect(a.moods.last, Mood.room);
    run(g, GameController.truthIdleMs + 500);
    expect(g.overlay, GameOverlay.none);

    // Stages 06–15 lead to the only ending choice.
    reachFinalStage(g);
    expect(g.stage, 15);
    expect(g.overlay, GameOverlay.truth);
    run(g, GameController.truthIdleMs + 500);
    expect(a.moods.last, Mood.truthEnd);
  });

  test('trusting the game cuts straight back to the lullaby and keeps it', () {
    final g = GameController(settings, startStage: 5, audio: a);
    reachFinalStage(g);
    a.clear();
    g.choose(GameOverlay.endTrust);
    expect(a.calls, containsAllInOrder(['play good', 'mood trust cut']));
    run(g, GameController.trustLoopMs + 100);
    expect(g.stage, 1);
    expect(a.moods, [Mood.trust], reason: 'the loop keeps the same song going');
  });

  test('not trusting the game opens the door to the open air', () {
    final g = GameController(settings, startStage: 5, audio: a);
    reachFinalStage(g);
    g.choose(GameOverlay.endDont);
    expect(a.played.last, Sfx.doorOpen);
    expect(a.moods.last, Mood.exit);
  });

  test(
    'typing ticks skip spaces and the ok/lie/voice lines; steps tick per tile',
    () {
      final g = GameController(settings, audio: a);
      run(g, 1000);
      expect(a.count(Sfx.type), 'MOVERIGHT.'.length);
      a.clear();
      g.onTile(const Tile(4, 0));
      run(g, 3000);
      expect(a.count(Sfx.step), 7);
      expect(a.count(Sfx.good), 1);
      expect(a.count(Sfx.type), 'OPENTHEDOOR.'.length);
    },
  );

  test('the stage card ticks as it types', () {
    final g = GameController(
      settings,
      startStage: 3,
      random: math.Random(2),
      audio: a,
    );
    g.onDoor();
    run(g, 1500);
    g.onDoor(); // through: the light transition starts right away
    a.clear();
    run(g, 1500);
    expect(a.count(Sfx.type), '04/WATCHING'.length);
  });

  test('glitch bursts sound and stumble; REDUCE GLITCH silences them', () {
    final g = GameController(
      settings,
      startStage: 3,
      random: math.Random(2),
      audio: a,
    );
    run(g, 20000);
    final heavy = a.count(Sfx.glitchHeavy);
    expect(heavy, greaterThanOrEqualTo(3));
    expect(a.calls.where((c) => c == 'hiccup heavy'), hasLength(heavy));

    settings.toggleReduceGlitch();
    a.clear();
    run(g, 20000);
    expect(a.count(Sfx.glitchHeavy), 0);
    expect(a.calls, isNot(contains('hiccup heavy')));

    g.onDoor();
    run(g, 1500);
    g.onDoor();
    run(g, 700);
    expect(a.played, contains(Sfx.fade));
    expect(a.played, isNot(contains(Sfx.light)));
  });

  test(
    'a stopped game sends no more cues, even with a stage about to be revealed',
    () {
      final g = GameController(
        settings,
        startStage: 3,
        random: math.Random(2),
        audio: a,
      );
      g.onDoor();
      run(g, 1500);
      g.onDoor(); // through: the light transition starts
      run(g, 600); // covered, stage 04 waiting underneath
      a.clear();
      g.stop(); // leaving for the menu
      run(g, 3000);
      expect(a.calls, isEmpty);
    },
  );

  test(
    'restarting hands back what a pause or a transition took from the music',
    () {
      final g = GameController(
        settings,
        startStage: 3,
        random: math.Random(2),
        audio: a,
      );
      g.onDoor();
      run(g, 1500);
      g.onDoor();
      run(g, 600); // covered
      a.clear();
      g.restart();
      expect(a.calls, ['reset', 'mood trust', 'uncover']);

      g.pause();
      a.clear();
      g.restart();
      expect(a.calls, ['reset', 'mood trust', 'duck false']);
    },
  );

  test('pause ducks the music and resume brings it back', () {
    final g = GameController(settings, audio: a);
    a.clear(); // the constructor already asked for the lullaby
    g.resume(); // not paused: nothing to undo
    expect(a.calls, isEmpty);
    g.pause();
    expect(a.calls, ['play pause', 'duck true']);
    g.resume();
    expect(a.calls.sublist(2), ['play resume', 'duck false']);
  });

  test('dial and wrong code', () {
    final g = GameController(settings, startStage: 2, audio: a);
    g.onCabinet();
    run(g, 2000);
    g
      ..dial(1, 1)
      ..dial(1, -1);
    expect(a.count(Sfx.dial), 2);
    g.dials = [9, 9, 9, 9];
    g.unlock();
    expect(a.played.last, Sfx.wrong);
  });
}
