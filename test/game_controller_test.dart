import 'package:dont_trust_the_game/game/game_controller.dart';
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

  test('path avoids the lamp and cabinet tiles', () {
    final p = GameController.path(const Tile(1, 4), const Tile(0, 1))!;
    expect(p.last, const Tile(0, 1));
    expect(p.any((t) => GameController.blocked(t.i, t.j)), isFalse);
    expect(GameController.path(const Tile(1, 4), const Tile(0, 3)), isNull);
  });

  test('full playthrough reaches all three endings', () {
    final g = GameController(settings);
    expect(g.stage, 1);
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
    g.onContinue();
    expect(g.current.text, "DON'T GO THERE.");

    // Disobey: pick up the key anyway.
    g.onTile(const Tile(5, 5));
    run(g, 4000);
    expect(g.stage, 3);
    expect(g.hasKey, isTrue);
    expect(g.scene.glitch, 1);

    // 03 UI GLITCH — open and go through the door.
    g.onDoor();
    run(g, 2000);
    expect(g.scene.doorOpen, isTrue);
    g.onDoor();
    run(g, 3000);

    // 04 WATCHING — idle comment, pause counter.
    expect(g.stage, 4);
    expect(g.scene.crack, isTrue);
    run(g, GameController.idleCommentMs + 500);
    expect(g.current.text, 'Why are you not moving?');
    g.pause();
    run(g, 5000); // frozen while paused
    expect(g.pauses, 1);
    g.resume();

    // 05 TRUTH — through the crack.
    g.onCrack();
    run(g, 4000);
    expect(g.stage, 5);
    expect(g.overlay, GameOverlay.truth);
    expect(g.scene.wallText, truthWallText);

    // Doing nothing is the true ending.
    run(g, GameController.truthIdleMs + 500);
    expect(g.overlay, GameOverlay.endTrue);
    expect(settings.endingsSeen, contains('endTrue'));
  });

  test('trusting the game loops back to room 01', () {
    final g = GameController(settings, startStage: 4);
    g.onCrack();
    run(g, 4000);
    g.choose(GameOverlay.endTrust);
    expect(g.overlay, GameOverlay.endTrust);
    run(g, GameController.trustLoopMs + 100);
    expect(g.stage, 1);
    expect(g.overlay, GameOverlay.none);
    expect(g.current.text, 'MOVE RIGHT.');
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
}
