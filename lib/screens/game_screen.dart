import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../game/overlays.dart';
import '../game/transition_overlay.dart';
import '../main.dart';
import '../widgets/common.dart';
import 'settings_screen.dart';

/// 03–08 + endings. The room is a Flame world; the HUD, terminal, puzzle,
/// pause, choice and ending layers are Flutter overlays on top of it.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  /// `--dart-define=START_STAGE=3` jumps straight into a stage for testing.
  static const startStage = int.fromEnvironment('START_STAGE', defaultValue: 1);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameController? _game;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _game ??= GameController(AppScope.of(context), startStage: GameScreen.startStage)
      ..start();
    _game!.systemReduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void dispose() {
    _game?.dispose();
    super.dispose();
  }

  void _toMenu() => Navigator.of(context).popUntil((r) => r.isFirst);

  Future<void> _openSettings() =>
      Navigator.of(context).push(fadeRoute(const SettingsScreen()));

  @override
  Widget build(BuildContext context) {
    final g = _game!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (g.paused) {
          g.resume();
        } else if (g.overlay == GameOverlay.puzzle || g.overlay == GameOverlay.log) {
          g.closeOverlay();
        } else if (g.canPause) {
          g.pause();
        } else {
          _toMenu();
        }
      },
      child: Scaffold(
        body: DesignFrame(
          child: ListenableBuilder(
            listenable: g,
            builder: (context, _) => _layers(g),
          ),
        ),
      ),
    );
  }

  double _roomTop(GameController g) => switch (g.overlay) {
        GameOverlay.puzzle => 60,
        GameOverlay.endDont => 120,
        GameOverlay.endTrue => 70,
        GameOverlay.endTrust => 96,
        _ when g.stage == 5 => 40,
        _ when g.continuePrompt => 70,
        _ => 96,
      };

  Widget _layers(GameController g) {
    final trustEnd = g.overlay == GameOverlay.endTrust;
    final showHud = (g.hudVisible || trustEnd) &&
        g.overlay != GameOverlay.endDont &&
        g.overlay != GameOverlay.endTrue;
    final showTerminal = g.stage < 5 && !g.paused || trustEnd;
    final unstable = (g.stage == 3 || g.stage == 4) && !trustEnd;
    final shakeDx = g.shake > 0 ? math.sin(g.shake * 40) * 6 * g.shake : 0.0;

    return Stack(children: [
      AnimatedPositioned(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        top: _roomTop(g),
        left: shakeDx,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: g.paused ? .28 : 1,
          child: IgnorePointer(ignoring: g.busy, child: RoomView(g.scene)),
        ),
      ),
      if (showTerminal)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: trustEnd ? const TrustEndingTerminal() : Terminal(g),
        ),
      if (g.paused) Positioned.fill(child: PauseOverlay(g, onSettings: _openSettings, onMenu: _toMenu)),
      if (showHud)
        Positioned(
          top: 26,
          left: 20,
          right: 20,
          child: Transform.translate(
            offset: g.glitch.jitter,
            child: Hud(g, forceTrust: trustEnd),
          ),
        ),
      if (unstable) const Positioned.fill(child: Scanlines()),
      Positioned.fill(child: SheetHost(g)),
      Positioned(left: 0, right: 0, bottom: 0, child: TruthChoice(g)),
      if (g.overlay == GameOverlay.endDont)
        Positioned(left: 28, right: 28, bottom: 46, child: DontTrustEnding(onLeave: _toMenu)),
      if (g.overlay == GameOverlay.endTrue) Positioned.fill(child: TrueEnding(onDone: _toMenu)),
      // Stage transitions sit above everything; the room swaps underneath.
      Positioned.fill(child: TransitionOverlay(g, roomTop: 96)),
    ]);
  }
}
