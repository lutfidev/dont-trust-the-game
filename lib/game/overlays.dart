import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'game_controller.dart';

const _redGhost = [Shadow(color: Color(0xB3E5484D), offset: Offset(-2, 0))];

// ------------------------------------------------------------------ HUD

class Hud extends StatelessWidget {
  const Hud(this.g, {super.key, this.forceTrust = false});
  final GameController g;
  final bool forceTrust;

  static const _labels = {
    1: '01 / TRUST',
    2: '02 / FIRST LIE',
    3: '03 / UI GL1TCH',
    4: '04 / WATCHING',
  };

  @override
  Widget build(BuildContext context) {
    final stage = forceTrust ? 1 : g.stage;
    final fx = g.glitch;
    final lying = stage >= 3;
    // Between bursts the HUD is what the design shows; during a burst the
    // game briefly lets its "real" labels slip through.
    final dot = lying || (stage == 2 && fx.bursting) ? C.warn : C.safe;
    final labelText = switch (stage) {
      3 => fx.flicker(_labels[3]!, '03 / UI GLITCH', k: 1),
      4 => fx.flicker(_labels[4]!, '04 / I SEE YOU', k: 1, chance: .45),
      _ => _labels[stage] ?? '',
    };
    final label = StageLabel(labelText, dot, dotAfter: stage == 3);
    final VoidCallback? onTap =
        forceTrust ? null : (g.paused ? g.resume : g.pause);
    final text = g.paused && !forceTrust
        ? '[ ▸ ]'
        : switch (stage) {
            2 => fx.flicker('[ II ]', '[ TRUST ME ]', k: 2, chance: .8),
            3 => fx.flicker('[ TRUST ME ]', '[ II ]', k: 2, chance: .5),
            4 => fx.flicker('[ TRUST ME ]', '[ WATCHING ]', k: 2, chance: .5),
            _ => '[ II ]',
          };

    if (stage == 3) {
      // The HUD swaps sides and the pause button leans off its grid.
      final btn = Transform.translate(
        offset: const Offset(3, 2),
        child: Transform.rotate(
          angle: -1.5 * math.pi / 180,
          child: HudButton(text,
              onTap: onTap,
              border: const Color(0xFF4A2426),
              shadows: const [Shadow(color: C.warn, offset: Offset(-2, 0))]),
        ),
      );
      return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [btn, label]);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        label,
        HudButton(text,
            onTap: onTap,
            shadows: lying ? const [Shadow(color: C.warn, offset: Offset(-2, 0))] : null),
      ],
    );
  }
}

// ------------------------------------------------------------------ Terminal

class Terminal extends StatelessWidget {
  const Terminal(this.g, {super.key});
  final GameController g;

  static const _colors = {
    LineKind.sys: C.muted,
    LineKind.cmd: C.ink,
    LineKind.lie: C.warn,
    LineKind.ok: C.safe,
    LineKind.voice: C.ink,
  };

  @override
  Widget build(BuildContext context) {
    final glitch = g.stage == 3;
    final dialogue = g.continuePrompt;
    final cur = g.current;
    final prev = g.log.length > 1
        ? g.log.sublist(math.max(0, g.log.length - 4), g.log.length - 1)
        : const <LogLine>[];

    final fx = g.glitch;
    var lineNo = 'L.${(g.lineCount + g.stage * 7).toString().padLeft(3, '0')}';
    if (glitch) lineNo = '${lineNo.substring(0, 3)}?${lineNo.substring(4)}';
    lineNo = fx.scramble(lineNo, amount: .4);
    final header = switch (g.stage) {
      3 => fx.flicker('SYST3M', 'SYSTEM', k: 3),
      4 => fx.flicker('SYSTEM', 'SYST3M', k: 3),
      _ => 'SYSTEM',
    };

    return Container(
      height: dialogue ? 330 : 270,
      decoration: BoxDecoration(
        color: C.panel,
        border: glitch ? null : const Border(top: BorderSide(color: C.terminalTop)),
      ),
      child: Stack(children: [
        if (glitch) ...[
          const FractionallySizedBox(
              widthFactor: .58, child: SizedBox(height: 1, child: ColoredBox(color: C.line))),
          const Positioned(
            top: 4,
            left: 360 * .58,
            right: 0,
            child: SizedBox(height: 1, child: ColoredBox(color: Color(0xFF3A2224))),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(header,
                      style: mono(10,
                          tracking: .24,
                          color: cur.kind == LineKind.lie ? C.warn : C.muted)),
                  Text(lineNo, style: mono(10, tracking: .24, color: C.muted)),
                ],
              ),
              for (final l in prev) ...[
                SizedBox(height: dialogue ? 12 : 10),
                Text(
                  l.display,
                  style: l.isVoice
                      ? serif(14, color: C.muted, height: 1.2)
                      : mono(12,
                          height: 1.4,
                          color: l.kind == LineKind.lie ? C.warn : C.muted),
                ),
              ],
              SizedBox(height: dialogue ? 12 : 10),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: _CurrentLine(g, glitch: glitch),
              ),
              const Spacer(),
              if (dialogue)
                Row(children: [
                  Expanded(
                    child: BlockButton('[ CONTINUE ]',
                        arrow: true,
                        padding: 16,
                        tracking: .18,
                        borderColor: C.borderBtn,
                        onTap: g.onContinue),
                  ),
                  const SizedBox(width: 8),
                  BlockButton('[ LOG ]',
                      kind: BtnKind.muted,
                      padding: 16,
                      tracking: .18,
                      expand: false,
                      borderColor: C.line,
                      onTap: g.showLog),
                ])
              else
                _Footer(g, swapped: glitch),
            ],
          ),
        ),
      ]),
    );
  }
}

class _CurrentLine extends StatelessWidget {
  const _CurrentLine(this.g, {required this.glitch});
  final GameController g;
  final bool glitch;

  @override
  Widget build(BuildContext context) {
    final cur = g.current;
    final voice = cur.isVoice;
    final lie = cur.kind == LineKind.lie;
    final size = voice ? 28.0 : lie ? 30.0 : 20.0;
    final color = Terminal._colors[cur.kind]!;
    final prefix = voice ? '' : '> ';
    var shown = prefix + cur.text.substring(0, g.typed);
    // Instructions tear apart for a moment during a burst (never the voice).
    if (g.stage >= 3 && !voice) shown = g.glitch.scramble(shown, amount: .1);
    final style = voice
        ? serif(size, color: color, height: 1.2)
        : mono(size,
            color: color,
            tracking: .02,
            weight: lie ? FontWeight.w600 : FontWeight.w500,
            height: 1.2,
            shadows: glitch ? _redGhost : null);

    final spans = <InlineSpan>[];
    final door = glitch ? (prefix + cur.text).indexOf('DOOR') : -1;
    if (door >= 0 && shown.length > door + 1) {
      // "D0OR": one glyph swaps for a red zero and jumps 3px.
      spans
        ..add(TextSpan(text: shown.substring(0, door + 1)))
        ..add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Transform.translate(
            offset: const Offset(0, -3),
            child: Text('0', style: style.copyWith(color: C.warn, shadows: const [])),
          ),
        ))
        ..add(TextSpan(text: shown.substring(door + 2)));
    } else {
      spans.add(TextSpan(text: shown));
    }
    spans.add(BlinkCursor.span(size, color));

    final text = Text.rich(TextSpan(children: spans), style: style);
    final cmd = cur.text;
    if (!glitch || !(cmd.contains('OPEN THE DOOR') || cmd.contains('TRUST ME'))) {
      return text;
    }
    return Stack(clipBehavior: Clip.none, children: [
      text,
      Positioned(
        top: -15,
        left: 30,
        child: Opacity(
          opacity: .75,
          child: Text("DON'T", style: mono(11, color: C.warn, tracking: .2)),
        ),
      ),
    ]);
  }
}

class _Footer extends StatelessWidget {
  const _Footer(this.g, {required this.swapped});
  final GameController g;
  final bool swapped;

  @override
  Widget build(BuildContext context) {
    final fx = g.glitch;
    final obey = g.stage >= 3;
    final verb = obey ? fx.flicker('OBEY', 'MOVE', k: 5, chance: .5) : 'MOVE';
    final watching = g.stage == 4 &&
        fx.flicker('', 'x', k: 6, chance: .35).isNotEmpty;
    final hint = watching
        ? Text("I KNOW WHERE YOU'LL TAP", style: mono(10, color: C.warn, tracking: .18))
        : Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'TAP A TILE TO '),
              TextSpan(
                  text: verb,
                  style: TextStyle(color: verb == 'OBEY' ? C.warn : C.muted)),
            ]),
            style: mono(10, color: C.muted, tracking: .18),
          );
    final slots = Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: C.line)),
        child: Text(g.hasKey ? 'KEY' : '', style: mono(9, tracking: .1)),
      ),
      const SizedBox(width: 6),
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(border: Border.all(color: C.rule)),
      ),
    ]);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: swapped ? [slots, hint] : [hint, slots],
    );
  }
}

// ------------------------------------------------------------------ Pause

class PauseOverlay extends StatelessWidget {
  const PauseOverlay(this.g, {super.key, required this.onSettings, required this.onMenu});
  final GameController g;
  final VoidCallback onSettings;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final comment = switch (g.stage) {
      3 => 'I changed the button. Did you notice?',
      4 => 'Why are you not moving?',
      _ => '',
    };
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x330B0B0C), Color(0xD90B0B0C)],
          stops: [0, .5],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 44),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(g.stage == 3 ? 'TRUST ME' : 'PAUSED',
              style: mono(11, color: C.muted, tracking: .3)),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(comment, style: serif(34, height: 1.1)),
          ],
          if (g.stage == 4) ...[
            const SizedBox(height: 10),
            Text('> YOU PAUSED ${g.pauses} ${g.pauses == 1 ? 'TIME' : 'TIMES'}.',
                style: mono(11, color: C.muted, tracking: .16)),
          ],
          const SizedBox(height: 36),
          BlockButton('[ RESUME ]', kind: BtnKind.primary, arrow: true, onTap: g.resume),
          const SizedBox(height: 10),
          BlockButton('[ SETTINGS ]', onTap: onSettings),
          const SizedBox(height: 10),
          BlockButton('[ MAIN MENU ]', kind: BtnKind.muted, onTap: onMenu),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Sheets

/// Slides the drawer puzzle or the log up from the bottom.
class SheetHost extends StatelessWidget {
  const SheetHost(this.g, {super.key});
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final Widget? sheet = switch (g.overlay) {
      GameOverlay.puzzle => PuzzleSheet(g, key: const ValueKey('pz')),
      GameOverlay.log => LogSheet(g, key: const ValueKey('log')),
      _ => null,
    };
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, a) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(a),
          child: child,
        ),
        child: sheet ?? const SizedBox.shrink(),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.onClose, required this.child});
  final String title;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 386,
      decoration: const BoxDecoration(
        color: C.sheet,
        border: Border(top: BorderSide(color: C.line)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: mono(10, color: C.muted, tracking: .24)),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('[ × ]', style: mono(10, tracking: .24)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class PuzzleSheet extends StatelessWidget {
  const PuzzleSheet(this.g, {super.key});
  final GameController g;

  static const _msgs = {
    PuzzleStatus.idle: ('', C.muted),
    PuzzleStatus.wrong: ('> WRONG.', C.muted),
    PuzzleStatus.lied: ('> WRONG. I TOLD YOU THE WRONG CODE.', C.warn),
    PuzzleStatus.open: ("> OPEN. YOU DIDN'T LISTEN. GOOD.", C.safe),
  };

  @override
  Widget build(BuildContext context) {
    final (msg, color) = _msgs[g.puzzleStatus]!;
    final open = g.puzzleStatus == PuzzleStatus.open;
    return _Sheet(
      title: open ? 'DRAWER · OPEN' : 'DRAWER · LOCKED',
      onClose: g.closeOverlay,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('> THE CODE IS 1-2-3-4.', style: mono(16, weight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('> TRUST ME.', style: mono(12, color: C.muted)),
          const SizedBox(height: 14),
          Row(children: [
            for (var k = 0; k < 4; k++) ...[
              if (k > 0) const SizedBox(width: 10),
              Expanded(child: _Dial(g.dials[k], (d) => g.dial(k, d))),
            ],
          ]),
          const SizedBox(height: 14),
          SizedBox(
            height: 16,
            child: Text(msg, style: mono(11, color: color, tracking: .14)),
          ),
          const Spacer(),
          BlockButton('[ UNLOCK ]', kind: BtnKind.primary, center: true, onTap: g.unlock),
        ],
      ),
    );
  }
}

class _Dial extends StatelessWidget {
  const _Dial(this.value, this.onStep);
  final int value;
  final ValueChanged<int> onStep;

  Widget _arrow(String s, int d) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onStep(d),
        child: SizedBox(
          height: 36,
          child: Center(child: glyphText(s, mono(10, color: C.dim))),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(border: Border.all(color: C.line)),
        child: Column(children: [
          _arrow('▲', 1),
          Container(
            height: 58,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: C.void_,
              border: Border.symmetric(horizontal: BorderSide(color: C.rule)),
            ),
            child: Text('$value', style: mono(32, weight: FontWeight.w500)),
          ),
          _arrow('▼', -1),
        ]),
      );
}

class LogSheet extends StatelessWidget {
  const LogSheet(this.g, {super.key});
  final GameController g;

  @override
  Widget build(BuildContext context) => _Sheet(
        title: 'LOG',
        onClose: g.closeOverlay,
        child: ListView(
          reverse: true,
          padding: const EdgeInsets.only(top: 8),
          children: [
            for (final l in g.log.reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  l.display,
                  style: l.isVoice
                      ? serif(16, color: C.ink)
                      : mono(12,
                          height: 1.4,
                          color: l.kind == LineKind.lie ? C.warn : C.dim),
                ),
              ),
          ],
        ),
      );
}

// ------------------------------------------------------------------ 05 Truth

class TruthChoice extends StatelessWidget {
  const TruthChoice(this.g, {super.key});
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final on = g.overlay == GameOverlay.truth;
    return IgnorePointer(
      ignoring: !on,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 700),
        opacity: on ? 1 : 0,
        child: Container(
          height: 430,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x000B0B0C), C.void_],
              stops: [0, .22],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('The game cannot control you if you stop listening.',
                  style: serif(31, height: 1.12)),
              const SizedBox(height: 28),
              BlockButton('[ TRUST THE GAME ]',
                  height: 50,
                  tracking: .18,
                  borderColor: C.borderBtn,
                  onTap: () => g.choose(GameOverlay.endTrust)),
              const SizedBox(height: 10),
              BlockButton("[ DON'T TRUST THE GAME ]",
                  height: 50,
                  tracking: .18,
                  borderColor: C.borderBtn,
                  onTap: () => g.choose(GameOverlay.endDont)),
              const SizedBox(height: 10),
              BlockButton('[ DO NOTHING ]',
                  kind: BtnKind.dashed,
                  height: 50,
                  tracking: .18,
                  onTap: () => g.choose(GameOverlay.endTrue)),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Endings

/// E1 — identical to the first gameplay screen; loops back without a transition.
class TrustEndingTerminal extends StatelessWidget {
  const TrustEndingTerminal({super.key});

  @override
  Widget build(BuildContext context) => Container(
        height: 270,
        decoration: const BoxDecoration(
          color: C.panel,
          border: Border(top: BorderSide(color: C.terminalTop)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SYSTEM', style: mono(10, tracking: .24, color: C.muted)),
                Text('L.001', style: mono(10, tracking: .24, color: C.muted)),
              ],
            ),
            const SizedBox(height: 10),
            Text('> YOU DID EVERYTHING I ASKED.',
                style: mono(21, weight: FontWeight.w500, height: 1.25)),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: '> RETURNING TO ROOM 01'),
                BlinkCursor.span(12, C.muted),
              ]),
              style: mono(12, color: C.muted),
            ),
            const Spacer(),
            Text('ENDING 1 / 3 · LOOP', style: mono(10, color: C.muted, tracking: .3)),
          ],
        ),
      );
}

/// E2 — the terminal is gone; the open door is the only light.
class DontTrustEnding extends StatelessWidget {
  const DontTrustEnding({super.key, required this.onLeave});
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) => _FadeIn(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('EXIT FOUND', style: mono(10, color: C.safe, tracking: .3)),
            const SizedBox(height: 14),
            Text('YOU STOPPED LISTENING.',
                style: mono(28, weight: FontWeight.w600, height: 1.1)),
            const SizedBox(height: 14),
            Text('> THE DOOR WAS NEVER LOCKED.', style: mono(12, color: C.dim)),
            const SizedBox(height: 36),
            BlockButton('[ LEAVE ]', kind: BtnKind.primary, arrow: true, onTap: onLeave),
            const SizedBox(height: 14),
            Text('ENDING 2 / 3 · EXIT', style: mono(10, color: C.muted, tracking: .3)),
          ],
        ),
      );
}

/// E3 — no walls, no buttons. The game stops giving instructions; any tap
/// (after a moment) quietly returns to the menu.
class TrueEnding extends StatefulWidget {
  const TrueEnding({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<TrueEnding> createState() => _TrueEndingState();
}

class _TrueEndingState extends State<TrueEnding> {
  bool _ready = false;
  late final Timer _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 2500), () => setState(() => _ready = true));
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _ready ? widget.onDone : null,
        child: Stack(children: [
          Positioned(
            left: 30,
            right: 30,
            bottom: 52,
            child: _FadeIn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You figured it out.', style: serif(40, height: 1.05)),
                  const SizedBox(height: 12),
                  Text("You don't have to play by my rules.",
                      style: serif(24, color: C.dim, height: 1.2)),
                  const SizedBox(height: 54),
                  Text('ENDING 3 / 3 · TRUE', style: mono(10, color: C.muted, tracking: .3)),
                ],
              ),
            ),
          ),
        ]),
      );
}

class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOut,
        builder: (_, v, c) => Opacity(opacity: v, child: c),
        child: child,
      );
}
