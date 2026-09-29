import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'game_controller.dart';

/// Covers the screen while the stage changes underneath.
///
/// * [TransitionKind.tear] — black bands slam shut from both sides with red
///   scan lines, hold on a stage card, then tear open again (02 → 03).
/// * [TransitionKind.light] — white light floods out of the door / crack,
///   holds on a dark stage card, then fades (03 → 04, 04 → 05).
class TransitionOverlay extends StatelessWidget {
  const TransitionOverlay(this.g, {super.key, required this.roomTop});
  final GameController g;

  /// Where the room canvas sits on screen, to place the light origin.
  final double roomTop;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StageTransition?>(
      valueListenable: g.transition,
      builder: (context, t, _) {
        if (t == null) return const SizedBox.shrink();
        return ValueListenableBuilder<int>(
          valueListenable: g.transitionClock,
          builder: (context, ms, _) {
            final light = t.kind == TransitionKind.light;
            final hold = ms >= t.coverMs && ms < t.totalMs - (light ? 500 : 300);
            final typedMs = ms - t.coverMs - 120;
            final chars = typedMs <= 0 ? 0 : math.min(t.card.length, typedMs ~/ 30);
            final ink = light ? C.void_ : C.ink;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: CustomPaint(
                size: Size.infinite,
                painter: light
                    ? _LightPainter(t, ms, t.origin.translate(0, roomTop))
                    : _TearPainter(t, ms),
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: hold ? 1 : 0,
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: t.card.substring(0, chars)),
                        BlinkCursor.span(12, ink),
                      ]),
                      style: mono(12, color: ink, tracking: .3),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

double _ease(double x) => Curves.easeInOutCubic.transform(x.clamp(0.0, 1.0));

class _TearPainter extends CustomPainter {
  _TearPainter(this.t, this.ms);
  final StageTransition t;
  final int ms;

  static const bands = 16;
  static const revealMs = 300;

  @override
  void paint(Canvas canvas, Size size) {
    final bh = size.height / bands;
    final rnd = math.Random(7);
    final closing = ms < t.coverMs;
    final reveal = ms > t.totalMs - revealMs;
    final black = Paint()..color = const Color(0xFF050506);

    for (var k = 0; k < bands; k++) {
      final delay = rnd.nextDouble() * .45;
      final fromLeft = rnd.nextBool();
      double cover;
      if (closing) {
        cover = _ease((ms / t.coverMs - delay) / (1 - delay));
      } else if (reveal) {
        final r = (ms - (t.totalMs - revealMs)) / revealMs;
        cover = 1 - _ease((r - delay * .6) / (1 - delay * .6));
      } else {
        cover = 1;
      }
      if (cover <= 0) continue;
      final w = size.width * cover;
      // Bands overshoot a few px so neighbours never leave a hairline gap.
      final rect = fromLeft
          ? Rect.fromLTWH(0, k * bh - .5, w, bh + 1)
          : Rect.fromLTWH(size.width - w, k * bh - .5, w, bh + 1);
      canvas.drawRect(rect, black);
      // The leading edge of a moving band flickers red / ink.
      if (cover < 1) {
        final edgeX = fromLeft ? rect.right : rect.left;
        canvas.drawRect(
          Rect.fromLTWH(edgeX - 2, rect.top, 4, rect.height),
          Paint()..color = (k.isEven ? C.warn : C.ink).withValues(alpha: .7),
        );
      }
    }

    // Scan lines stutter across the screen while it closes.
    if (closing || reveal) {
      final lines = math.Random(ms ~/ 50);
      for (var k = 0; k < 3; k++) {
        final y = lines.nextDouble() * size.height;
        canvas.drawRect(
          Rect.fromLTWH(0, y, size.width, 1 + lines.nextDouble() * 2),
          Paint()..color = (k == 0 ? C.warn : C.ink).withValues(alpha: .5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TearPainter old) => old.ms != ms;
}

class _LightPainter extends CustomPainter {
  _LightPainter(this.t, this.ms, this.origin);
  final StageTransition t;
  final int ms;
  final Offset origin;

  static const fadeMs = 500;

  @override
  void paint(Canvas canvas, Size size) {
    final far = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((c) => (c - origin).distance).reduce(math.max);

    if (ms < t.coverMs) {
      final p = Curves.easeInCubic.transform(ms / t.coverMs);
      // A tall sliver of light first, then it swallows the screen.
      final r = 6 + far * p;
      final rect = Rect.fromCenter(
        center: origin,
        width: r * 2 * math.max(p, .08),
        height: r * 2,
      );
      canvas.drawOval(
        rect.inflate(18 * (1 - p)),
        Paint()
          ..shader = RadialGradient(colors: [
            C.ink,
            C.ink.withValues(alpha: .85),
            C.ink.withValues(alpha: 0),
          ], stops: const [0, .7, 1])
              .createShader(rect.inflate(18 * (1 - p))),
      );
      return;
    }
    final fadeStart = t.totalMs - fadeMs;
    final a = ms < fadeStart ? 1.0 : 1 - _ease((ms - fadeStart) / fadeMs);
    canvas.drawRect(Offset.zero & size, Paint()..color = C.ink.withValues(alpha: a));
  }

  @override
  bool shouldRepaint(_LightPainter old) => old.ms != ms;
}
