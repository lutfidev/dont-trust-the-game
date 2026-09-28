import 'dart:ui';

/// Isometric projection shared by every room piece.
///
/// The room canvas is 360×340 logical px (same as the design). Tiles are 2:1,
/// 48×24, in a 6×6 grid. Screen position = ((i−j)·w/2, (i+j)·h/2 − z).
abstract final class Iso {
  static const double w = 48;
  static const double h = 24;
  static const int n = 6;
  static const double wallHeight = 110;
  static const double ox = 180;
  static const double oy = 150;
  static const Size canvas = Size(360, 340);

  static Offset p(double i, double j, [double z = 0]) =>
      Offset(ox + (i - j) * w / 2, oy + (i + j) * h / 2 - z);

  /// Inverse of [p] at z = 0: fractional tile coordinates for a canvas point.
  static (double, double) tileAt(Offset o) {
    final a = (o.dx - ox) / (w / 2); // i − j
    final b = (o.dy - oy) / (h / 2); // i + j
    return ((a + b) / 2, (b - a) / 2);
  }

  static Path poly(List<Offset> pts) => Path()..addPolygon(pts, true);

  static Rect bounds(List<Offset> pts) {
    var l = pts.first.dx, t = pts.first.dy, r = l, b = t;
    for (final o in pts) {
      if (o.dx < l) l = o.dx;
      if (o.dx > r) r = o.dx;
      if (o.dy < t) t = o.dy;
      if (o.dy > b) b = o.dy;
    }
    return Rect.fromLTRB(l, t, r, b);
  }
}
