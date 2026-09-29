import 'dart:math' as math;
import 'dart:ui';

/// Player designs. [pill] is the one from the approved design; the others are
/// alternatives explored for production (see `docs/characters.png`).
enum CharacterStyle { pill, cloak, block }

/// The four isometric facings. `se` walks toward +i (screen right-down),
/// `sw` toward +j (left-down), `ne` toward −j, `nw` toward −i.
enum Facing {
  se(1, .5, front: true),
  sw(-1, .5, front: true),
  ne(1, -.5, front: false),
  nw(-1, -.5, front: false);

  const Facing(this.dx, this.dy, {required this.front});
  final double dx, dy;

  /// Whether the face is visible (walking toward the camera).
  final bool front;

  /// Facing for a move of (di, dj) tiles; null when not moving.
  static Facing? of(double di, double dj) {
    if (di.abs() < 1e-6 && dj.abs() < 1e-6) return null;
    if (di.abs() >= dj.abs()) return di > 0 ? se : nw;
    return dj > 0 ? sw : ne;
  }
}

enum Pose {
  idle(4, 600),
  walk(8, 42);

  const Pose(this.frames, this.frameMs);
  final int frames;

  /// Walk: 8 frames per stride = 2 tiles of 170ms each.
  final int frameMs;
}

/// Sprite frame box in room-canvas units; feet sit at [anchor].
const frameSize = Size(32, 48);
const frameAnchor = Offset(16, 42);

const _ink = Color(0xFFF1EEE7);
const _hi = Color(0xFFF4F1EA);
const _lo = Color(0xFFABA79F);
const _mid = Color(0xFFD6D2C9);
const _dark = Color(0xFF16161A);

/// Paints one frame with the feet at the canvas origin.
/// [t] is the phase within the pose cycle, 0 ≤ t < 1.
void paintCharacter(Canvas c, CharacterStyle style, Facing f, Pose pose, double t) {
  final walk = pose == Pose.walk;
  final w = 2 * math.pi * t;

  // Motion: walking bobs twice per stride with squash on contact; idle breathes.
  final bob = walk ? -2.2 * math.sin(w).abs() : -.5 * (1 + math.sin(w)) / 2;
  final sy = walk ? 1 - .045 * math.cos(2 * w) : 1 + .018 * math.sin(w);
  final sx = walk ? 1 + .03 * math.cos(2 * w) : 1.0;
  final lean = walk ? (f.dx * 3 + .8 * math.sin(w)) * math.pi / 180 : 0.0;

  // Shadow stays on the floor and shrinks as the body lifts.
  final shadow = 1 + bob / 22;
  c.drawOval(
    Rect.fromCenter(center: Offset.zero, width: 20 * shadow, height: 10 * shadow),
    Paint()..color = const Color(0x8C000000),
  );

  // Feet alternate along the walking direction.
  if (walk || style != CharacterStyle.block) {
    final amp = walk ? 3.0 * math.sin(w) : 0.0;
    final v = Offset(f.dx, f.dy) / Offset(f.dx, f.dy).distance;
    final feet = Paint()..color = _lo;
    for (final (side, s) in [(-1.0, 1.0), (1.0, -1.0)]) {
      final o = Offset(side * 3, -1.2) + v * amp * s;
      c.drawOval(Rect.fromCenter(center: o, width: 4.6, height: 2.4), feet);
    }
  }

  c
    ..save()
    ..translate(0, bob)
    ..rotate(lean)
    ..scale(sx, sy);
  switch (style) {
    case CharacterStyle.pill:
      _pill(c, f, walk ? 0 : -.5 * math.sin(w));
    case CharacterStyle.cloak:
      _cloak(c, f);
    case CharacterStyle.block:
      _block(c, f);
  }
  c.restore();
}

Paint _grad(Rect r) => Paint()
  ..shader = Gradient.linear(r.centerLeft, r.centerRight, const [_hi, _lo]);

void _pill(Canvas c, Facing f, double headDy) {
  const body = Rect.fromLTWH(-6.5, -25, 13, 21);
  c.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(6.5)), _grad(body));
  final head = Offset(0, -31 + headDy);
  c.drawCircle(head, 5.5, Paint()..color = f.front ? _ink : const Color(0xFFE2DED5));
  if (f.front) {
    // A small dark visor shows which way it looks.
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: head + Offset(f.dx * 2, .4), width: 4.4, height: 1.8),
        const Radius.circular(.9),
      ),
      Paint()..color = _dark,
    );
  }
}

void _cloak(Canvas c, Facing f) {
  final robe = Path()
    ..moveTo(-4, -25)
    ..lineTo(4, -25)
    ..lineTo(9, -4)
    ..quadraticBezierTo(0, -1.5, -9, -4)
    ..close();
  c.drawPath(robe, _grad(const Rect.fromLTWH(-9, -25, 18, 23)));
  const hood = Offset(0, -30);
  if (!f.front) {
    // Hood point trailing behind.
    c.drawPath(
      Path()
        ..moveTo(-3, -33)
        ..lineTo(-f.dx * 7, -27)
        ..lineTo(3, -30)
        ..close(),
      Paint()..color = _mid,
    );
  }
  c.drawCircle(hood, 6.2, Paint()..color = f.front ? _ink : _mid);
  if (f.front) {
    c.drawOval(
      Rect.fromCenter(center: hood + Offset(f.dx * 1.8, .9), width: 5.2, height: 6.2),
      Paint()..color = _dark,
    );
    c.drawLine(Offset(f.dx * 1.5, -22), Offset(f.dx * 2.4, -6),
        Paint()
          ..color = const Color(0xFFC9C5BC)
          ..strokeWidth = .8);
  }
}

void _block(Canvas c, Facing f) {
  void cube(double cx, double baseY, double half, double h, {bool eyes = false}) {
    final q = half / 2;
    Offset p(double x, double y) => Offset(cx + x, baseY + y);
    final top = [p(0, -h - q), p(half, -h), p(0, -h + q), p(-half, -h)];
    final left = [p(-half, -h), p(0, -h + q), p(0, q), p(-half, 0)];
    final right = [p(0, -h + q), p(half, -h), p(half, 0), p(0, q)];
    c
      ..drawPath(Path()..addPolygon(left, true), Paint()..color = _mid)
      ..drawPath(Path()..addPolygon(right, true), Paint()..color = _lo)
      ..drawPath(Path()..addPolygon(top, true), Paint()..color = _hi);
    if (eyes && f.front) {
      // SE looks out of the right face, SW out of the left face.
      final s = f.dx;
      final eye = Paint()..color = _dark;
      for (final k in [.3, .7]) {
        final base = Offset(cx + s * half * k, baseY - h * .55 + q * (s > 0 ? 1 - k : 1 - k));
        c.drawRect(Rect.fromCenter(center: base, width: 1.4, height: 2.2), eye);
      }
    }
  }

  cube(0, -4, 6.5, 15);
  cube(0, -22, 5, 9, eyes: true);
}

/// Which design the game uses: `--dart-define=CHARACTER=cloak|block`.
final CharacterStyle activeCharacter = CharacterStyle.values.asNameMap()[
        const String.fromEnvironment('CHARACTER', defaultValue: 'pill')] ??
    CharacterStyle.pill;
