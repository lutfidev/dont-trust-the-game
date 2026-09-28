import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../room/room_scene.dart';
import '../settings.dart';
import '../theme.dart';

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

/// The whole story as a state machine: stages 01 TRUST → 05 TRUTH.
///
/// All timing runs through [tick] on a pause-aware clock, so scheduled beats,
/// typing and walking freeze while the pause menu is open.
class GameController extends ChangeNotifier {
  GameController(this.settings, {int startStage = 1}) {
    _reset(startStage);
  }

  final SettingsStore settings;
  final RoomScene scene = RoomScene();

  static const walkStepMs = 170;
  static const idleCommentMs = 7000;
  static const truthIdleMs = 12000;
  static const trustLoopMs = 4200;
  static const realCode = [4, 0, 7, 1];
  static const toldCode = [1, 2, 3, 4];

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
  bool flash = false;
  double shake = 0;
  List<int> dials = [4, 0, 0, 0];
  PuzzleStatus puzzleStatus = PuzzleStatus.idle;

  int _leftWalks = 0;
  bool _saidLeft = false, _saidIdle = false;
  int _idleMs = 0, _truthMs = 0, _typeMs = 0, _walkMs = 0;
  final Queue<Tile> _walk = Queue();
  void Function(Tile)? _walkThen;
  final List<(int, VoidCallback)> _tasks = [];

  Timer? _clock;
  Stopwatch? _sw;

  LogLine get current => log.last;
  bool get typing => typed < current.text.length;
  bool get busy => paused || overlay != GameOverlay.none || continuePrompt;
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

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------- setup

  void _reset(int s) {
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
    flash = false;
    dials = [4, 0, 0, 0];
    puzzleStatus = PuzzleStatus.idle;
    _leftWalks = 0;
    _saidLeft = _saidIdle = false;
    _idleMs = _truthMs = 0;
    _setRoom(normal: true);
    scene
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
          ..glitch = 1
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
      ..glitch = 0
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
    final live = stage < 5;
    scene
      ..onTile = live ? onTile : null
      ..onDoor = live ? onDoor : null
      ..onCabinet = live ? onCabinet : null
      ..onCrack = live ? onCrack : null;
  }

  void restart([int s = 1]) {
    _reset(s);
    notifyListeners();
  }

  // ---------------------------------------------------------------- clock

  void tick(int ms) {
    if (paused) return;
    var changed = false;

    if (typing) {
      _typeMs += ms;
      final per = settings.speed.msPerChar;
      while (_typeMs >= per && typing) {
        _typeMs -= per;
        typed++;
        changed = true;
      }
    } else {
      _typeMs = 0;
    }

    if (_walk.isNotEmpty) {
      _walkMs += ms;
      while (_walkMs >= walkStepMs && _walk.isNotEmpty) {
        _walkMs -= walkStepMs;
        scene.player = _walk.removeFirst();
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

  void _say(String t, LineKind k) {
    log.add(LogLine(t, k));
    lineCount++;
    typed = 0;
    _typeMs = 0;
    if (k == LineKind.lie) _buzz();
  }

  void _doFlash() {
    flash = true;
    _buzz();
    if (settings.screenShake) shake = 1;
    _later(140, () => flash = false);
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
      scene
        ..keyOnFloor = false
        ..highlights = const [];
      _say('...YOU FOUND IT ANYWAY.', LineKind.sys);
      _later(1400, () {
        _doFlash();
        stage = 3;
        step = Step.door2;
        scene
          ..glitch = 1
          ..doorHint = true
          ..wallText = const [];
        _syncRoom();
        _say('USE THE KEY.', LineKind.cmd);
        _later(900, () => _say('OPEN THE DOOR.', LineKind.cmd));
      });
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
        _say('GO THROUGH. TRUST ME.', LineKind.cmd);
      case Step.through:
        _doFlash();
        _enterStage4(announce: true);
      case _ when stage == 4:
        _say('Not this time.', LineKind.voice);
      case Step.drawer || Step.key:
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
      ..crack = true
      ..glitch = 1;
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
      _doFlash();
      stage = 5;
      step = Step.truth;
      _setRoom(normal: false);
      scene
        ..secret = true
        ..wallText = truthWallText
        ..player = const Tile(1, 2);
      _syncRoom();
      _say('...', LineKind.sys);
      _later(1300, () {
        _truthMs = 0;
        overlay = GameOverlay.truth;
      });
    });
    notifyListeners();
  }

  // ---------------------------------------------------------------- puzzle

  void dial(int k, int delta) {
    dials = [...dials]..[k] = (dials[k] + delta + 10) % 10;
    puzzleStatus = PuzzleStatus.idle;
    notifyListeners();
  }

  void unlock() {
    if (puzzleStatus == PuzzleStatus.open) return;
    if (listEquals(dials, realCode)) {
      puzzleStatus = PuzzleStatus.open;
      step = Step.wait;
      _later(1100, () {
        overlay = GameOverlay.none;
        scene.drawerOpen = true;
        _say('...', LineKind.sys);
        _later(1300, () {
          _say('I LIED.', LineKind.lie);
          continuePrompt = true;
        });
      });
    } else {
      puzzleStatus =
          listEquals(dials, toldCode) ? PuzzleStatus.lied : PuzzleStatus.wrong;
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
    notifyListeners();
  }

  // ---------------------------------------------------------------- pause / endings

  bool get canPause => stage < 5 && (overlay == GameOverlay.none || overlay == GameOverlay.log);

  void pause() {
    if (!canPause || paused) return;
    paused = true;
    pauses++;
    notifyListeners();
  }

  void resume() {
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
      _setRoom(normal: true);
      scene
        ..player = const Tile(1, 4)
        ..highlights = const [TileHighlight(Tile(4, 0), C.safe)];
      scene.onTile = scene.onDoor = scene.onCabinet = scene.onCrack = null;
      _later(trustLoopMs, () => _reset(1));
    } else if (ending == GameOverlay.endDont) {
      _setRoom(normal: true);
      scene
        ..noCabinet = true
        ..doorOpen = true
        ..player = const Tile(4, 1);
    } else {
      _setRoom(normal: false);
      scene
        ..noWalls = true
        ..player = const Tile(2, 2);
    }
  }
}
