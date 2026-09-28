import 'dart:math' as math;

import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';

import '../room/iso.dart';
import '../room/room_game.dart';
import '../room/room_scene.dart';
import '../theme.dart';

/// Lays screens out on the design's 360-wide canvas and scales it to the
/// device. Height is whatever the device aspect gives (min 700), so
/// top- and bottom-anchored elements keep their design offsets.
class DesignFrame extends StatelessWidget {
  const DesignFrame({super.key, required this.child, this.background = C.void_});
  final Widget child;
  final Color background;

  static const width = 360.0;
  static const minHeight = 700.0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          final scale = math.min(box.maxWidth / width, box.maxHeight / minHeight);
          return FittedBox(
            child: SizedBox(
              width: width,
              height: box.maxHeight / scale,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
                child: child,
              ),
            ),
          );
        }),
      ),
    );
  }
}

enum BtnKind { primary, outline, muted, dashed }

/// The bracketed "[ LABEL ]" buttons used everywhere.
class BlockButton extends StatefulWidget {
  const BlockButton(
    this.label, {
    super.key,
    required this.onTap,
    this.kind = BtnKind.outline,
    this.height,
    this.arrow = false,
    this.center = false,
    this.fontSize,
    this.tracking,
    this.borderColor,
    this.padding = 18,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onTap;
  final BtnKind kind;
  final double? height;
  final bool arrow;
  final bool center;
  final double? fontSize;
  final double? tracking;
  final Color? borderColor;
  final double padding;
  final bool expand;

  @override
  State<BlockButton> createState() => _BlockButtonState();
}

class _BlockButtonState extends State<BlockButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.kind == BtnKind.primary;
    final fg = switch (widget.kind) {
      BtnKind.primary => C.void_,
      BtnKind.muted || BtnKind.dashed => C.dim,
      BtnKind.outline => C.ink,
    };
    final size = widget.fontSize ?? (primary ? 13 : 12);
    final style = mono(size,
        color: fg,
        tracking: widget.tracking ?? .2,
        weight: primary ? FontWeight.w600 : FontWeight.w400);
    final label = glyphText(widget.label, style);
    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.padding),
      child: Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: widget.center
            ? MainAxisAlignment.center
            : widget.arrow
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.start,
        children: [label, if (widget.arrow) glyphText('▸', style)],
      ),
    );
    final border = widget.borderColor ?? C.border;
    Widget box = Container(
      height: widget.height ?? (primary ? 52 : 48),
      decoration: BoxDecoration(
        color: primary ? C.ink : Colors.transparent,
        border: primary || widget.kind == BtnKind.dashed
            ? null
            : Border.all(color: border),
      ),
      child: content,
    );
    if (widget.kind == BtnKind.dashed) {
      box = CustomPaint(painter: DashedRectPainter(border), child: box);
    }
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 80),
          opacity: _down ? .6 : 1,
          child: box,
        ),
      ),
    );
  }
}

class DashedRectPainter extends CustomPainter {
  DashedRectPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 3.0, gap = 3.0;
    final r = Offset.zero & size;
    final edges = [
      (r.topLeft, r.topRight),
      (r.topRight, r.bottomRight),
      (r.bottomRight, r.bottomLeft),
      (r.bottomLeft, r.topLeft),
    ];
    for (final (a, b) in edges) {
      final len = (b - a).distance, dir = (b - a) / len;
      for (var d = 0.0; d < len; d += dash + gap) {
        canvas.drawLine(
            a + dir * d + dir * .5, a + dir * math.min(d + dash, len) + dir * .5, p);
      }
    }
  }

  @override
  bool shouldRepaint(DashedRectPainter old) => old.color != color;
}

/// Blinking block cursor, 1s steps, sized to the surrounding text.
class BlinkCursor extends StatefulWidget {
  const BlinkCursor({super.key, required this.fontSize, required this.color});
  final double fontSize;
  final Color color;

  static InlineSpan span(double fontSize, Color color) => WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: BlinkCursor(fontSize: fontSize, color: color),
      );

  @override
  State<BlinkCursor> createState() => _BlinkCursorState();
}

class _BlinkCursorState extends State<BlinkCursor>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.fontSize;
    return Padding(
      padding: EdgeInsets.only(left: 5),
      child: Transform.translate(
        offset: Offset(0, s * .1),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Opacity(
            opacity: _c.value < .5 ? 1 : 0,
            child: SizedBox(
              width: s * .55,
              height: s * .95,
              child: ColoredBox(color: widget.color),
            ),
          ),
        ),
      ),
    );
  }
}

/// 1px ink lines every 3px at 4% — only while the game is unstable.
class Scanlines extends StatelessWidget {
  const Scanlines({super.key});

  @override
  Widget build(BuildContext context) =>
      const IgnorePointer(child: CustomPaint(painter: _ScanPainter(), size: Size.infinite));
}

class _ScanPainter extends CustomPainter {
  const _ScanPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = C.ink.withValues(alpha: .04);
    for (var y = size.height - 1; y >= 0; y -= 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(_ScanPainter old) => false;
}

/// A Flame isometric room in a 360×340 box.
class RoomView extends StatefulWidget {
  const RoomView(this.scene, {super.key});
  final RoomScene scene;

  @override
  State<RoomView> createState() => _RoomViewState();
}

class _RoomViewState extends State<RoomView> {
  late final RoomGame _game = RoomGame(widget.scene);

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
        size: Iso.canvas,
        child: GameWidget(game: _game),
      );
}

/// "01 / TRUST" with its status dot.
class StageLabel extends StatelessWidget {
  const StageLabel(this.text, this.dot, {super.key, this.dotAfter = false});
  final String text;
  final Color dot;
  final bool dotAfter;

  @override
  Widget build(BuildContext context) {
    final d = Container(
        width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle));
    final t = Text(text, style: mono(10, color: C.dim, tracking: .22));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: dotAfter
          ? [t, const SizedBox(width: 8), d]
          : [d, const SizedBox(width: 8), t],
    );
  }
}

/// The small outlined HUD button ("[ II ]", "[ ← ]").
class HudButton extends StatelessWidget {
  const HudButton(this.label,
      {super.key, this.onTap, this.border = C.borderHi, this.shadows});
  final String label;
  final VoidCallback? onTap;
  final Color border;
  final List<Shadow>? shadows;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: border)),
            child: glyphText(label, mono(11, tracking: .16, shadows: shadows)),
          ),
        ),
      );
}

Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => page,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    );

/// Plex Mono has no ▸ ▲ ▼, so those are drawn as small triangles inline.
Widget glyphText(String s, TextStyle style) {
  final spans = <InlineSpan>[];
  final buf = StringBuffer();
  for (final ch in s.characters) {
    final dir = const {'▸': AxisDirection.right, '▲': AxisDirection.up, '▼': AxisDirection.down}[ch];
    if (dir == null) {
      buf.write(ch);
      continue;
    }
    if (buf.isNotEmpty) spans.add(TextSpan(text: buf.toString()));
    buf.clear();
    spans.add(WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Tri(dir, size: style.fontSize! * .62, color: style.color!),
    ));
  }
  if (buf.isNotEmpty) spans.add(TextSpan(text: buf.toString()));
  return Text.rich(TextSpan(children: spans), style: style, maxLines: 1, softWrap: false);
}

class Tri extends StatelessWidget {
  const Tri(this.dir, {super.key, required this.size, required this.color});
  final AxisDirection dir;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _TriPainter(dir, color),
      );
}

class _TriPainter extends CustomPainter {
  _TriPainter(this.dir, this.color);
  final AxisDirection dir;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height, m = w * .12;
    final pts = switch (dir) {
      AxisDirection.right => [Offset(m, m), Offset(w - m, h / 2), Offset(m, h - m)],
      AxisDirection.left => [Offset(w - m, m), Offset(m, h / 2), Offset(w - m, h - m)],
      AxisDirection.up => [Offset(m, h - m * 2), Offset(w / 2, m * 2), Offset(w - m, h - m * 2)],
      AxisDirection.down => [Offset(m, m * 2), Offset(w / 2, h - m * 2), Offset(w - m, m * 2)],
    };
    canvas.drawPath(Path()..addPolygon(pts, true), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TriPainter old) => old.dir != dir || old.color != color;
}
