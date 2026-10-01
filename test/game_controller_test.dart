import 'dart:math' as math;

import 'package:dont_trust_the_game/audio/cues.dart';
import 'package:dont_trust_the_game/game/game_controller.dart';
import 'package:dont_trust_the_game/game/glitch.dart';
import 'package:dont_trust_the_game/game/route_challenge.dart';
import 'package:dont_trust_the_game/room/room_scene.dart';
import 'package:dont_trust_the_game/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsStore settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'vibration': false});
    settings = await SettingsStore.load();
  });

  /// Advances the pause-aware clock in 16ms frames.
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

  test('path avoids the lamp and cabinet tiles', () {
    final p = GameController.path(const Tile(1, 4), const Tile(0, 1))!;
    expect(p.last, const Tile(0, 1));
    expect(p.any((t) => GameController.blocked(t.i, t.j)), isFalse);
    expect(GameController.path(const Tile(1, 4), const Tile(0, 3)), isNull);
  });

  test('analog input walks along the isometric grid and stops on release', () {
    final g = GameController(settings, random: math.Random(1));
    g.setAnalogInput(const Offset(1, .5)); // screen down-right, grid +i
    run(g, 240);
    expect(g.scene.player, const Tile(2, 4));

    g.setAnalogInput(Offset.zero);
    run(g, 500);
    expect(g.scene.player, const Tile(2, 4));
  });

  test('pausing clears a held analog direction', () {
    final g = GameController(settings, random: math.Random(1));
    g.setAnalogInput(const Offset(1, .5));
    run(g, 100);
    g.pause();
    g.resume();
    run(g, 500);

    expect(g.scene.player, const Tile(1, 4));
  });

  test('full playthrough reaches all three endings', () {
    final g = GameController(settings, random: math.Random(1));
    expect(g.stage, 1);
    expect(g.glitch.unease, Unease.none);
    expect(g.current.text, 'MOVE RIGHT.');

    // 01 TRUST — follow the instruction.
    g.onTile(const Tile(4, 0));
    run(g, 3000);
    expect(g.current.text, 'OPEN THE DOOR.');
    g.onDoor();
    run(g, 2000);

    // 02 FIRST LIE — the told code is wrong, the scratched one works.
    expect(g.stage, 2);
    expect(g.scene.wallText, contains(codeWallText));
    g.onCabinet();
    run(g, 2000);
    expect(g.overlay, GameOverlay.puzzle);
    g.dials = [1, 2, 3, 4];
    g.unlock();
    expect(g.puzzleStatus, PuzzleStatus.lied);
    g.dials = [...GameController.realCode];
    g.unlock();
    run(g, 3000);
    expect(g.overlay, GameOverlay.none);
    expect(g.scene.drawerOpen, isTrue);
    expect(g.current.kind, LineKind.lie);
    expect(g.continuePrompt, isTrue);
    expect(g.glitch.unease, Unease.hint);
    g.onContinue();
    expect(g.current.text, "DON'T GO THERE.");

    // Disobey: pick up the key anyway.
    g.onTile(const Tile(5, 5));
    run(g, 4000);
    expect(g.stage, 3);
    expect(g.hasKey, isTrue);
    expect(g.glitch.unease, Unease.broken);

    // 03 UI GLITCH — open and go through the door.
    g.onDoor();
    run(g, 2000);
    expect(g.scene.doorOpen, isTrue);
    g.onDoor();
    run(g, 3000);

    // 04 WATCHING — idle comment, pause counter.
    expect(g.stage, 4);
    expect(g.transition.value, isNull);
    expect(g.glitch.unease, Unease.watching);
    expect(g.scene.crack, isFalse);
    run(g, GameController.idleCommentMs + 500);
    expect(g.current.text, 'Why are you not moving?');
    g.pause();
    run(g, 5000); // frozen while paused
    expect(g.pauses, 1);
    g.resume();

    findEchoes(g);
    expect(g.scene.crack, isTrue);

    // 05 TRUTH is a checkpoint, not an ending.
    g.onCrack();
    run(g, 5000);
    expect(g.stage, 5);
    run(g, GameController.truthIdleMs + 500);
    expect(g.overlay, isNot(GameOverlay.truth));

    // 06–15 — increasingly long routes across four maps.
    reachFinalStage(g);
    expect(g.stage, 15);
    expect(g.overlay, GameOverlay.truth);
    expect(g.mood, Mood.room);

    // Doing nothing is the true ending.
    run(g, GameController.truthIdleMs + 500);
    expect(g.overlay, GameOverlay.endTrue);
    expect(settings.endingsSeen, contains('endTrue'));
  });

  test('trusting the game loops back to room 01', () {
    final g = GameController(settings, startStage: 5);
    g.choose(GameOverlay.endTrust);
    expect(g.overlay, GameOverlay.none, reason: 'Truth is a checkpoint');
    reachFinalStage(g);
    g.choose(GameOverlay.endTrust);
    expect(g.overlay, GameOverlay.endTrust);
    run(g, GameController.trustLoopMs + 100);
    expect(g.stage, 1);
    expect(g.overlay, GameOverlay.none);
    expect(g.current.text, 'MOVE RIGHT.');
  });

  test('stage 05 truth checkpoint continues instead of ending on idle', () {
    final g = GameController(settings, startStage: 5);
    run(g, GameController.truthIdleMs + 500);
    expect(g.stage, 5);
    expect(g.overlay, GameOverlay.none);
    expect(g.scene.secret, isTrue);

    g.onCrack();
    run(g, 2000);
    expect(g.stage, 6);
    expect(g.routeTargets, isNotEmpty);
  });

  test('all route stages rise in length and timed pressure', () {
    final g = GameController(settings, startStage: 6);
    final firstLength = g.routeTotal;
    for (var stage = 6; stage <= 15; stage++) {
      expect(g.stage, stage);
      if (stage < 12) {
        expect(g.routeSecondsRemaining, 0);
      } else {
        expect(g.routeSecondsRemaining, greaterThan(0));
      }
      solveRoute(g);
      if (stage < 15) {
        expect(g.scene.crack, isTrue);
        g.onCrack();
        run(g, 2000);
      }
    }
    run(g, 1000);
    expect(g.routeTotal, greaterThan(firstLength));
    expect(g.overlay, GameOverlay.truth);
  });

  test('each route target and exit is reachable around map obstacles', () {
    for (final challenge in RouteChallenge.all) {
      var position = const Tile(1, 4);
      for (final target in challenge.route) {
        final path = GameController.path(
          position,
          target,
          obstacles: challenge.obstacles,
        );
        expect(path, isNotNull, reason: 'stage ${challenge.stage}: $target');
        position = target;
      }
      expect(
        GameController.path(
          position,
          GameController.routeExitTile,
          obstacles: challenge.obstacles,
        ),
        isNotNull,
        reason: 'stage ${challenge.stage} exit',
      );
    }
  });

  test('a wrong route marker resets the sequence and costs time', () {
    final g = GameController(settings, startStage: 12);
    final before = g.routeSecondsRemaining;
    g.onTile(g.routeTargets.first);
    run(g, 220);
    expect(g.routeProgress, 1);
    g.onTile(g.routeTargets[3]);
    run(g, GameController.walkStepMs + 80);
    expect(g.routeProgress, 0);
    expect(g.routeSecondsRemaining, lessThan(before));
  });

  test('ending choices are ignored until stage 15 is solved', () {
    final g = GameController(settings, startStage: 5);
    g.choose(GameOverlay.endDont);
    expect(g.overlay, GameOverlay.none);
    reachFinalStage(g);
    g.choose(GameOverlay.endDont);
    expect(g.overlay, GameOverlay.endDont);
  });

  test('stage 04 crack opens only after all three echoes are found', () {
    final g = GameController(settings, startStage: 4);
    expect(g.scene.crack, isFalse);
    expect(g.scene.highlights, hasLength(GameController.echoTiles.length));

    g.onCrack();
    expect(g.transition.value, isNull);

    for (final (index, tile) in GameController.echoTiles.indexed) {
      g.onTile(tile);
      run(g, 2500);
      expect(g.echoesFound, index + 1);
      expect(g.scene.crack, index == GameController.echoTiles.length - 1);
    }

    g.onCrack();
    expect(g.transition.value, isNotNull);
  });

  test('direct stage start initializes route and map obstacle state', () {
    final first = GameController(settings, startStage: 6);
    expect(first.stage, 6);
    expect(first.routeTargets, isNotEmpty);
    expect(first.scene.map, RoomMap.archive);
    expect(first.current.text, RouteChallenge.at(6).instruction);

    final late = GameController(settings, startStage: 15);
    expect(late.stage, 15);
    expect(late.scene.map, RoomMap.core);
    expect(late.scene.obstacles, isNotEmpty);
  });

  test('stage 04 notices the player always going left', () {
    final g = GameController(settings, startStage: 4);
    g.onTile(const Tile(1, 5));
    run(g, 1000);
    g.onTile(const Tile(0, 5));
    run(g, 1500);
    expect(g.current.text, 'You always go left.');
    expect(g.current.isVoice, isTrue);
  });

  test('the assist setting turns itself back on', () async {
    settings.toggleAssist();
    expect(settings.assist, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(settings.assist, isTrue);
    expect(settings.assistMessage, 'NO.');
  });

  test('stage changes happen while the transition covers the screen', () {
    final g = GameController(settings, startStage: 3, random: math.Random(2));
    g.onDoor();
    run(g, 1500);
    g.onDoor(); // go through
    run(g, 700); // walk (0 tiles) + light cover
    final t = g.transition.value!;
    expect(t.kind, TransitionKind.light);
    expect(t.card, '04 / WATCHING');
    expect(g.stage, 4, reason: 'swapped under cover');
    expect(g.busy, isTrue);
    expect(g.canPause, isFalse);
    run(g, t.totalMs);
    expect(g.transition.value, isNull);
    expect(g.current.text, 'WELCOME BACK TO ROOM 01.');
  });

  test('glitch bursts only where the story allows them', () {
    final d = GlitchDirector(math.Random(3));
    var bursts = 0;
    void runFor(int ms) {
      var was = false;
      for (var t = 0; t < ms; t += 16) {
        d.tick(16);
        if (d.bursting && !was) bursts++;
        was = d.bursting;
      }
    }

    d.unease = Unease.none;
    runFor(20000);
    expect(bursts, 0);
    expect(d.fx.active, isFalse);

    d.unease = Unease.broken;
    expect(d.fx.slices, isNotEmpty, reason: 'steady slices between bursts');
    runFor(20000);
    expect(bursts, greaterThanOrEqualTo(4));

    // Labels only change mid-burst.
    d.unease = Unease.none;
    expect(d.flicker('A', 'B'), 'A');
    d.burst(ms: 100);
    expect(d.scramble('OPEN THE DOOR.'), hasLength(14));
  });

  test('reduce glitch stops bursts but keeps the steady look', () {
    final d = GlitchDirector(math.Random(4))..unease = Unease.broken;
    final rest = d.fx.slices;
    d.reduced = true;
    var bursts = 0;
    for (var t = 0; t < 20000; t += 16) {
      d.tick(16);
      if (d.bursting) bursts++;
    }
    expect(bursts, 0);
    d.burst(ms: 300);
    expect(d.bursting, isFalse, reason: 'transitions do not force a burst');
    expect(d.fx.slices, rest);
    expect(d.flicker('[ TRUST ME ]', '[ II ]'), '[ TRUST ME ]');
    expect(d.scramble('OPEN THE DOOR.'), 'OPEN THE DOOR.');
  });

  test(
    'the controller follows the setting and the OS reduce-motion flag',
    () async {
      final g = GameController(settings, startStage: 3, random: math.Random(5));
      g.tick(16);
      expect(g.glitch.reduced, isFalse);
      settings.toggleReduceGlitch();
      g.tick(16);
      expect(g.glitch.reduced, isTrue);
      settings.toggleReduceGlitch();
      g.systemReduceMotion = true;
      g.tick(16);
      expect(g.glitch.reduced, isTrue);
    },
  );
}
