import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../audio/cues.dart';
import '../audio/game_audio.dart';
import '../room/character.dart';
import '../room/iso.dart';
import '../room/room_scene.dart';
import '../settings.dart';
import '../theme.dart';
import 'glitch.dart';

enum LineKind { sys, cmd, lie, ok, voice }

class LogLine {
  const LogLine(this.text, this.kind);
  final String text;
  final LineKind kind;

  bool get isVoice => kind == LineKind.voice;

  /// Terminal lines are prefixed with "> "; the serif voice is not.
  String get display => isVoice ? text : '> $text';
}

enum Step { move, wait, door1, drawer, key, door2, through, watch, truth }

enum GameOverlay { none, puzzle, log, truth, endTrust, endDont, endTrue }

enum PuzzleStatus { idle, wrong, lied, open }

/// How a stage change is covered: a black glitch tear, or light flooding in
/// from a point in the room (the door, the crack).
enum TransitionKind { tear, light }

class StageTransition {
  StageTransition(this.kind, this.card, {this.origin = Offset.zero});
  final TransitionKind kind;

  /// Stage card shown while the screen is covered, e.g. "03 / UI GL1TCH".
  final String card;

  /// Where the light comes from, in room-canvas coordinates.
  final Offset origin;
  int elapsed = 0;

  int get coverMs => kind == TransitionKind.tear ? 380 : 450;
  int get totalMs => kind == TransitionKind.tear ? 1550 : 1700;
  int get revealMs => totalMs - coverMs;

  /// Characters of [card] typed so far: typing starts 120ms after the screen
  /// is covered, one character every 30ms.
  int get cardChars {
    final ms = elapsed - coverMs - 120;
    return ms <= 0 ? 0 : math.min(card.length, ms ~/ 30);
  }

  /// How long the screen takes to open up again at the end: the tear's bands
  /// pull back quicker than the light (or the reduced fade) fades. Both the
  /// overlay's painters and the audio's reveal cue go by this.
  int outMs({required bool reduced}) =>
      kind == TransitionKind.tear && !reduced ? 300 : 500;
}

/// The whole story as a state machine: stages 01 TRUST → 05 TRUTH.
///
/// All timing runs through [tick] on a pause-aware clock, so scheduled beats,
/// typing and walking freeze while the pause menu is open.
class GameController extends ChangeNotifier {
  GameController(this.settings,
      {int startStage = 1, math.Random? random, this.audio = const SilentAudio()})
      : glitch = GlitchDirector(random) {
    scene.fx = glitch.fx;
    _reset(startStage);
  }

  final SettingsStore settings;
  final RoomScene scene = RoomScene();
  final GlitchDirector glitch;

  /// Where the game's cues go; silent unless the app provides audio.
  final GameAudio audio;

  /// The OS "remove animations / reduce motion" setting, set by the screen.
  bool systemReduceMotion = false;

  /// The running stage transition; drives its overlay every frame.
  final ValueNotifier<StageTransition?> transition = ValueNotifier(null);

  /// Elapsed ms of [transition]; ticks every frame so only its overlay rebuilds.
  final ValueNotifier<int> transitionClock = ValueNotifier(0);

  static const walkStepMs = 170;
  static const idleCommentMs = 7000;
  static const truthIdleMs = 12000;
  static const trustLoopMs = 4200;
  static const realCode = [4, 0, 7, 1];
  static const toldCode = [1, 2, 3, 4];

  /// Light sources for the transitions, in room-canvas coordinates.
  static final doorLight = Iso.p(4.25, 0, 35);
  static final crackLight = Iso.p(0, 1.66, 52);

  late int stage;
  late Step step;
  final List<LogLine> log = [];
  int lineCount = 0;
  int typed = 0;
  bool paused = false;
  int pauses = 0;
  GameOverlay overlay = GameOverlay.none;
  bool hasKey = false;
  bool continuePrompt = false;
  double shake = 0;
  List<int> dials = [4, 0, 0, 0];
  PuzzleStatus puzzleStatus = PuzzleStatus.idle;

  int _leftWalks = 0;
  bool _saidLeft = false, _saidIdle = false, _lied = false;
  int _idleMs = 0, _truthMs = 0, _typeMs = 0, _walkMs = 0, _steps = 0;
  final Queue<Tile> _walk = Queue();
  void Function(Tile)? _walkThen;
  final List<(int, VoidCallback)> _tasks = [];

  Timer? _clock;
  Stopwatch? _sw;
  bool _stopped = false;

  LogLine get current => log.last;
  bool get typing => typed < current.text.length;
  bool get busy =>
      paused || overlay != GameOverlay.none || continuePrompt || transition.value != null;
  bool get hudVisible => stage < 5;
  bool get isEnding =>
      overlay == GameOverlay.endTrust ||
      overlay == GameOverlay.endDont ||
      overlay == GameOverlay.endTrue;

  void start() {
    _sw = Stopwatch()..start();
    _clock = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final ms = _sw!.elapsedMilliseconds;
      _sw!.reset();
      tick(ms);
    });
  }

  /// Freezes the game for good (leaving for the menu): no more beats, so no
  /// more cues either. The audio belongs to the menu from here on.
  void stop() {
    _stopped = true;
    _clock?.cancel();
  }

  @override
  void dispose() {
    stop();
    transition.dispose();
    transitionClock.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- setup

  void _reset(int s) {
    // A restart can come mid-pause or mid-transition: what those asked of the
    // audio is undone at the end, once the new stage has picked its music.
    final ducked = paused, covered = transition.value != null;
    _tasks.clear();
    _walk.clear();
    _walkThen = null;
    stage = 1;
    step = Step.move;
    log
      ..clear()
      ..addAll(const [
        LogLine('SYSTEM READY.', LineKind.sys),
        LogLine('MOVE RIGHT.', LineKind.cmd),
      ]);
    lineCount = 2;
    typed = 0;
    paused = false;
    pauses = 0;
    overlay = GameOverlay.none;
    hasKey = false;
    continuePrompt = false;
    transition.value = null;
    _lied = false;
    dials = [4, 0, 0, 0];
    puzzleStatus = PuzzleStatus.idle;
    _leftWalks = 0;
    _saidLeft = _saidIdle = false;
    _idleMs = _truthMs = 0;
    _setRoom(normal: true);
    scene
      ..facing = Facing.se
      ..player = const Tile(1, 4)
      ..highlights = const [TileHighlight(Tile(4, 0), C.safe)];

    switch (s) {
      case 2:
        stage = 2;
        step = Step.drawer;
        scene
          ..player = const Tile(3, 1)
          ..highlights = const []
          ..wallText = const [codeWallText];
        _replaceLog(const [
          LogLine("IT'S LOCKED.", LineKind.sys),
          LogLine('THE KEY IS IN THE DRAWER.', LineKind.cmd),
        ]);
      case 3:
        stage = 3;
        step = Step.door2;
        hasKey = true;
        scene
          ..player = const Tile(4, 2)
          ..highlights = const []
          ..drawerOpen = true
          ..doorHint = true;
        _replaceLog(const [
          LogLine('USE THE KEY.', LineKind.cmd),
          LogLine('OPEN THE DOOR.', LineKind.cmd),
        ]);
      case 4:
        _enterStage4(announce: false);
        _replaceLog(const [
          LogLine('WELCOME BACK TO ROOM 01.', LineKind.sys),
          LogLine("DON'T TOUCH THE WALL.", LineKind.cmd),
        ]);
    }
    _syncRoom();
    if (ducked) audio.duck(false);
    if (covered) audio.uncover();
  }

  void _replaceLog(List<LogLine> lines) {
    log
      ..clear()
      ..addAll(lines);
    lineCount = lines.length;
  }

  void _setRoom({required bool normal}) {
    scene
      ..doorOpen = false
      ..drawerOpen = false
      ..keyOnFloor = false
      ..highlights = const []
      ..doorHint = false
      ..crack = false
      ..secret = false
      ..noWalls = false
      ..noDoor = !normal
      ..noCabinet = !normal
      ..noLamp = !normal
      ..wallText = const [];
  }

  /// Keeps stage-dependent visuals and tap handlers in step with the state.
  void _syncRoom() {
    scene.doorColor = stage >= 3 ? C.warn : C.safe;
    glitch.unease = switch (stage) {
      3 => Unease.broken,
      4 => Unease.watching,
      2 when _lied => Unease.hint,
      _ => Unease.none,
    };
    final live = stage < 5;
    scene
      ..onTile = live ? onTile : null
      ..onDoor = live ? onDoor : null
      ..onCabinet = live ? onCabinet : null
      ..onCrack = live ? onCrack : null;
    _syncMusic();
  }

  /// The music for this moment (see docs/superpowers/specs/2026-09-30-audio-design.md).
  Mood get mood => switch (overlay) {
        GameOverlay.endTrust => Mood.trust,
        GameOverlay.endDont => Mood.exit,
        GameOverlay.endTrue => Mood.truthEnd,
        _ => switch (stage) {
            5 => Mood.room,
            4 => Mood.watching,
            3 => Mood.broken,
            // "I LIED." hangs in silence until CONTINUE.
            2 when _lied => continuePrompt ? Mood.silence : Mood.lie,
            _ => Mood.trust,
          },
      };

  /// Ending TRUST cuts straight back to the lullaby, as if nothing happened.
  void _syncMusic() => audio.mood(mood, cut: overlay == GameOverlay.endTrust);

  void restart([int s = 1]) {
    _reset(s);
    notifyListeners();
  }

  // ---------------------------------------------------------------- clock

  void tick(int ms) {
    if (paused || _stopped) return;
    var changed = false;

    if (typing) {
      _typeMs += ms;
      final per = settings.speed.msPerChar;
      while (_typeMs >= per && typing) {
        _typeMs -= per;
        typed++;
        changed = true;
        _typeTick(current.kind, current.text[typed - 1]);
      }
    } else {
      _typeMs = 0;
    }

    if (_walk.isNotEmpty) {
      _walkMs += ms;
      while (_walkMs >= walkStepMs && _walk.isNotEmpty) {
        _walkMs -= walkStepMs;
        scene.player = _walk.removeFirst();
        audio.play(stage == 4 ? Sfx.stepWatch : Sfx.step,
            rate: (_steps++).isEven ? .96 : 1.04);
        changed = true;
        if (_walk.isEmpty) {
          final then = _walkThen;
          _walkThen = null;
          then?.call(scene.player!);
        }
      }
    }

    if (_tasks.isNotEmpty) {
      final due = <VoidCallback>[];
      for (var k = 0; k < _tasks.length; k++) {
        final (left, fn) = _tasks[k];
        _tasks[k] = (left - ms, fn);
        if (left - ms <= 0) due.add(fn);
      }
      _tasks.removeWhere((t) => t.$1 <= 0);
      for (final fn in due) {
        fn();
      }
      changed |= due.isNotEmpty;
    }

    glitch.reduced = settings.reduceGlitch || systemReduceMotion;
    final wasBursting = glitch.bursting;
    if (glitch.tick(ms)) changed = true;
    // Only bursts the glitch director starts on its own make a sound; forced
    // ones (transitions, the lie) have their own.
    if (!wasBursting && glitch.bursting) {
      audio
        ..play(glitch.heavy ? Sfx.glitchHeavy : Sfx.glitchLight)
        ..hiccup(heavy: glitch.heavy);
    }

    final tr = transition.value;
    if (tr != null) {
      final typedBefore = tr.cardChars;
      tr.elapsed += ms;
      transitionClock.value = tr.elapsed;
      if (tr.cardChars > typedBefore) _typeTick(LineKind.sys, tr.card[tr.cardChars - 1]);
    }

    if (shake > 0) {
      shake = (shake - ms / 300).clamp(0, 1);
      changed = true;
    }

    if (stage == 4 && step == Step.watch && !_saidIdle && overlay == GameOverlay.none &&
        _walk.isEmpty) {
      _idleMs += ms;
      if (_idleMs > idleCommentMs) {
        _saidIdle = true;
        _say('Why are you not moving?', LineKind.voice);
        changed = true;
      }
    }

    if (overlay == GameOverlay.truth) {
      _truthMs += ms;
      if (_truthMs > truthIdleMs) {
        _end(GameOverlay.endTrue);
        changed = true;
      }
    }

    if (changed) notifyListeners();
  }

  void _later(int ms, VoidCallback fn) => _tasks.add((ms, fn));

  /// Key tick for terminal text. Spaces and the ok / lie / voice lines (which
  /// have their own cue) stay silent.
  void _typeTick(LineKind kind, String char) {
    if ((kind == LineKind.sys || kind == LineKind.cmd) && char != ' ') {
      audio.play(Sfx.type);
    }
  }

  void _say(String t, LineKind k) {
    log.add(LogLine(t, k));
    lineCount++;
    typed = 0;
    _typeMs = 0;
    switch (k) {
      case LineKind.lie:
        _buzz();
        audio
          ..play(Sfx.lie)
          ..tapeStop();
      case LineKind.ok:
        audio.play(Sfx.good);
      case LineKind.voice:
        audio.play(Sfx.voice);
      case LineKind.sys || LineKind.cmd:
        break;
    }
  }

  /// Covers the screen, swaps the stage in [onCovered] while nothing is
  /// visible, then reveals it. [afterReveal] runs once the screen is clear.
  void _transition(StageTransition t,
      {required VoidCallback onCovered, VoidCallback? afterReveal}) {
    glitch.reduced = settings.reduceGlitch || systemReduceMotion;
    final reduced = glitch.reduced;
    transition.value = t;
    transitionClock.value = 0;
    glitch.burst(ms: t.coverMs, heavy: t.kind == TransitionKind.tear);
    audio
      ..play(reduced
          ? Sfx.fade
          : t.kind == TransitionKind.tear
              ? Sfx.tear
              : Sfx.light)
      ..cover(Duration(milliseconds: t.coverMs));
    _later(t.coverMs, () {
      _buzz();
      if (settings.screenShake) shake = 1;
      onCovered();
      // The new stage's music starts as the screen opens up again.
      _later(t.revealMs - t.outMs(reduced: reduced), () {
        audio.uncover();
        if (t.kind == TransitionKind.tear && !reduced) audio.play(Sfx.tearOpen);
      });
      _later(t.revealMs, () {
        transition.value = null;
        afterReveal?.call();
      });
    });
  }

  void _buzz() {
    if (settings.vibration) HapticFeedback.mediumImpact();
  }

  // ---------------------------------------------------------------- walking

  static bool blocked(int i, int j) =>
      i < 0 || j < 0 || i > 5 || j > 5 || (i == 0 && (j == 0 || j == 3 || j == 4));

  /// Breadth-first path on the 6×6 grid, excluding the start tile.
  static List<Tile>? path(Tile a, Tile b) {
    if (blocked(b.i, b.j)) return null;
    final prev = <Tile, Tile?>{a: null};
    final q = Queue<Tile>()..add(a);
    while (q.isNotEmpty) {
      final c = q.removeFirst();
      if (c == b) {
        final out = <Tile>[];
        for (Tile? p = c; prev[p] != null; p = prev[p]) {
          out.insert(0, p!);
        }
        return out;
      }
      for (final (di, dj) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final n = Tile(c.i + di, c.j + dj);
        if (blocked(n.i, n.j) || prev.containsKey(n)) continue;
        prev[n] = c;
        q.add(n);
      }
    }
    return null;
  }

  void _walkTo(Tile t, [void Function(Tile)? then]) {
    final from = scene.player!;
    final p = path(from, t);
    if (p == null) return;
    _idleMs = 0;
    if (stage == 4 && (t.i - t.j) - (from.i - from.j) < 0) _leftWalk();
    _walk
      ..clear()
      ..addAll(p);
    _walkMs = 0;
    _walkThen = null;
    if (p.isEmpty) {
      then?.call(t);
    } else {
      _walkThen = then;
    }
  }

  void _leftWalk() {
    _leftWalks++;
    if (_leftWalks >= 2 && !_saidLeft) {
      _saidLeft = true;
      _later(500, () => _say('You always go left.', LineKind.voice));
    }
  }

  // ---------------------------------------------------------------- input

  void onTile(Tile t) {
    if (busy) return;
    _walkTo(t, _arrive);
    notifyListeners();
  }

  void _arrive(Tile n) {
    if (step == Step.move && n.i >= 4 && n.j <= 1) {
      step = Step.wait;
      scene.highlights = const [];
      _say('GOOD.', LineKind.ok);
      _later(900, () {
        _say('OPEN THE DOOR.', LineKind.cmd);
        step = Step.door1;
        scene.doorHint = true;
      });
    }
    if (step == Step.key && n == const Tile(5, 5)) {
      step = Step.wait;
      hasKey = true;
      audio.play(Sfx.key);
      scene
        ..keyOnFloor = false
        ..highlights = const [];
      _say('...YOU FOUND IT ANYWAY.', LineKind.sys);
      _later(1400, () => _transition(
            StageTransition(TransitionKind.tear, '03 / UI GL1TCH'),
            onCovered: () {
              stage = 3;
              step = Step.door2;
              scene
                ..doorHint = true
                ..wallText = const [];
              _syncRoom();
            },
            afterReveal: () {
              _say('USE THE KEY.', LineKind.cmd);
              _later(900, () => _say('OPEN THE DOOR.', LineKind.cmd));
            },
          ));
    }
  }

  void onDoor() {
    if (busy) return;
    _walkTo(const Tile(4, 0), (n) {
      _arrive(n);
      _doorAction();
    });
    notifyListeners();
  }

  void _doorAction() {
    switch (step) {
      case Step.door1:
        step = Step.wait;
        scene.doorHint = false;
        audio.play(Sfx.doorLocked);
        _say("IT'S LOCKED.", LineKind.sys);
        _later(1100, () {
          stage = 2;
          step = Step.drawer;
          scene.wallText = const [codeWallText];
          _syncRoom();
          _say('THE KEY IS IN THE DRAWER.', LineKind.cmd);
        });
      case Step.door2:
        step = Step.through;
        scene
          ..doorOpen = true
          ..doorHint = false;
        audio.play(Sfx.doorOpen);
        _say('GO THROUGH. TRUST ME.', LineKind.cmd);
      case Step.through:
        step = Step.wait;
        _transition(
          StageTransition(TransitionKind.light, '04 / WATCHING', origin: doorLight),
          onCovered: () => _enterStage4(announce: false),
          afterReveal: () {
            _say('WELCOME BACK TO ROOM 01.', LineKind.sys);
            _later(1500, () => _say("DON'T TOUCH THE WALL.", LineKind.cmd));
          },
        );
      case _ when stage == 4:
        _say('Not this time.', LineKind.voice);
      case Step.drawer || Step.key:
        audio.play(Sfx.doorLocked);
        _say('LOCKED.', LineKind.sys);
      default:
        break;
    }
  }

  void _enterStage4({required bool announce}) {
    stage = 4;
    step = Step.watch;
    hasKey = false;
    _setRoom(normal: true);
    scene
      ..player = const Tile(1, 4)
      ..crack = true;
    _idleMs = 0;
    _syncRoom();
    if (announce) {
      _say('WELCOME BACK TO ROOM 01.', LineKind.sys);
      _later(1500, () => _say("DON'T TOUCH THE WALL.", LineKind.cmd));
    }
  }

  void onCabinet() {
    if (busy) return;
    _walkTo(const Tile(1, 3), (_) => _cabinetAction());
    notifyListeners();
  }

  void _cabinetAction() {
    if (step == Step.drawer) {
      overlay = GameOverlay.puzzle;
      puzzleStatus = PuzzleStatus.idle;
    } else if (scene.drawerOpen) {
      _say('STILL EMPTY.', LineKind.sys);
    } else if (stage == 4) {
      _say('Nothing there. There never was.', LineKind.voice);
    } else if (stage == 1) {
      _say('NOT YET.', LineKind.sys);
    }
  }

  void onCrack() {
    if (busy || stage != 4) return;
    _walkTo(const Tile(0, 1), (_) {
      audio.play(Sfx.crack);
      _transition(
        StageTransition(TransitionKind.light, '05 / TRUTH', origin: crackLight),
        onCovered: () {
          stage = 5;
          step = Step.truth;
          _setRoom(normal: false);
          scene
            ..secret = true
            ..wallText = truthWallText
            ..facing = Facing.nw // facing the opening
            ..player = const Tile(1, 2);
          _syncRoom();
          _say('...', LineKind.sys);
        },
        afterReveal: () => _later(1300, () {
          _truthMs = 0;
          overlay = GameOverlay.truth;
        }),
      );
    });
    notifyListeners();
  }

  // ---------------------------------------------------------------- puzzle

  void dial(int k, int delta) {
    dials = [...dials]..[k] = (dials[k] + delta + 10) % 10;
    audio.play(Sfx.dial, rate: delta > 0 ? 1.08 : .94);
    puzzleStatus = PuzzleStatus.idle;
    notifyListeners();
  }

  void unlock() {
    if (puzzleStatus == PuzzleStatus.open) return;
    if (listEquals(dials, realCode)) {
      puzzleStatus = PuzzleStatus.open;
      audio.play(Sfx.unlock);
      step = Step.wait;
      _later(1100, () {
        overlay = GameOverlay.none;
        scene.drawerOpen = true;
        audio.play(Sfx.drawerOpen);
        _say('...', LineKind.sys);
        _later(1300, () {
          _say('I LIED.', LineKind.lie);
          continuePrompt = true;
          // From here on the UI is allowed to slip, just a little.
          _lied = true;
          _syncRoom();
          glitch.burst(ms: 220, heavy: false);
        });
      });
    } else {
      puzzleStatus =
          listEquals(dials, toldCode) ? PuzzleStatus.lied : PuzzleStatus.wrong;
      audio.play(puzzleStatus == PuzzleStatus.lied ? Sfx.wrongLied : Sfx.wrong);
      if (puzzleStatus == PuzzleStatus.lied) _buzz();
    }
    notifyListeners();
  }

  void closeOverlay() {
    if (overlay == GameOverlay.puzzle && puzzleStatus == PuzzleStatus.open) return;
    if (overlay == GameOverlay.puzzle || overlay == GameOverlay.log) {
      overlay = GameOverlay.none;
      notifyListeners();
    }
  }

  void showLog() {
    overlay = GameOverlay.log;
    notifyListeners();
  }

  void onContinue() {
    if (!continuePrompt) return;
    continuePrompt = false;
    if (overlay == GameOverlay.log) overlay = GameOverlay.none;
    step = Step.key;
    scene
      ..keyOnFloor = true
      ..highlights = const [TileHighlight(Tile(5, 5), C.warn)];
    _say("DON'T GO THERE.", LineKind.cmd);
    _syncMusic();
    notifyListeners();
  }

  // ---------------------------------------------------------------- pause / endings

  bool get canPause =>
      stage < 5 &&
      transition.value == null &&
      (overlay == GameOverlay.none || overlay == GameOverlay.log);

  void pause() {
    if (!canPause || paused) return;
    paused = true;
    pauses++;
    audio
      ..play(Sfx.pause)
      ..duck(true);
    notifyListeners();
  }

  void resume() {
    if (paused) {
      audio
        ..play(Sfx.resume)
        ..duck(false);
    }
    paused = false;
    _idleMs = 0;
    _sw?.reset();
    notifyListeners();
  }

  void choose(GameOverlay ending) {
    if (overlay != GameOverlay.truth) return;
    _end(ending);
    notifyListeners();
  }

  void _end(GameOverlay ending) {
    overlay = ending;
    settings.markEnding(ending.name);
    if (ending == GameOverlay.endTrust) {
      audio.play(Sfx.good); // "YOU DID EVERYTHING I ASKED."
      _setRoom(normal: true);
      scene
        ..player = const Tile(1, 4)
        ..highlights = const [TileHighlight(Tile(4, 0), C.safe)];
      scene.onTile = scene.onDoor = scene.onCabinet = scene.onCrack = null;
      _later(trustLoopMs, () => _reset(1));
    } else if (ending == GameOverlay.endDont) {
      audio.play(Sfx.doorOpen);
      _setRoom(normal: true);
      scene
        ..noCabinet = true
        ..doorOpen = true
        ..facing = Facing.ne // back turned, looking at the way out
        ..player = const Tile(4, 1);
    } else {
      _setRoom(normal: false);
      scene
        ..noWalls = true
        ..player = const Tile(2, 2);
    }
    _syncMusic();
  }
}
