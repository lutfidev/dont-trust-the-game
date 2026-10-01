import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;

import '../game/glitch.dart';
import '../theme.dart';
import 'character.dart';
import 'iso.dart';
import 'player_sheet.dart';
import 'room_scene.dart';

Offset _p(double i, double j, [double z = 0]) => Iso.p(i, j, z);
Paint _fill(Color c, [double opacity = 1]) =>
    Paint()..color = c.withValues(alpha: c.a * opacity);
Paint _stroke(Color c, double width, [double opacity = 1]) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..color = c.withValues(alpha: c.a * opacity);
Color _a(Color c, double opacity) => c.withValues(alpha: opacity);

class _RoomPalette {
  const _RoomPalette({
    required this.leftWall,
    required this.backWall,
    required this.cornice,
    required this.tileA,
    required this.tileB,
    required this.obstacleTop,
    required this.obstacleLeft,
    required this.obstacleRight,
  });

  final Color leftWall, backWall, cornice, tileA, tileB;
  final Color obstacleTop, obstacleLeft, obstacleRight;
}

_RoomPalette _paletteFor(RoomMap map) => switch (map) {
  RoomMap.home => const _RoomPalette(
    leftWall: Color(0xFF17171A),
    backWall: Color(0xFF1F1F22),
    cornice: Color(0xFF2B2B2F),
    tileA: Color(0xFF18181B),
    tileB: Color(0xFF1B1B1E),
    obstacleTop: Color(0xFFB5B1A8),
    obstacleLeft: Color(0xFF68666A),
    obstacleRight: Color(0xFF3E3D42),
  ),
  RoomMap.truth => const _RoomPalette(
    leftWall: Color(0xFF182126),
    backWall: Color(0xFF25323A),
    cornice: Color(0xFF3D5961),
    tileA: Color(0xFF182328),
    tileB: Color(0xFF203037),
    obstacleTop: Color(0xFFA2C5C1),
    obstacleLeft: Color(0xFF45676C),
    obstacleRight: Color(0xFF2A454D),
  ),
  RoomMap.archive => const _RoomPalette(
    leftWall: Color(0xFF182326),
    backWall: Color(0xFF25383A),
    cornice: Color(0xFF536F64),
    tileA: Color(0xFF1B2929),
    tileB: Color(0xFF243433),
    obstacleTop: Color(0xFFB5AD8C),
    obstacleLeft: Color(0xFF74705B),
    obstacleRight: Color(0xFF484A42),
  ),
  RoomMap.greenhouse => const _RoomPalette(
    leftWall: Color(0xFF14221C),
    backWall: Color(0xFF203329),
    cornice: Color(0xFF4D7550),
    tileA: Color(0xFF18281E),
    tileB: Color(0xFF223326),
    obstacleTop: Color(0xFF9BAF64),
    obstacleLeft: Color(0xFF4D7045),
    obstacleRight: Color(0xFF304A35),
  ),
  RoomMap.tower => const _RoomPalette(
    leftWall: Color(0xFF24191A),
    backWall: Color(0xFF382323),
    cornice: Color(0xFF79403A),
    tileA: Color(0xFF281D1E),
    tileB: Color(0xFF352425),
    obstacleTop: Color(0xFFCB8B62),
    obstacleLeft: Color(0xFF8E4F3D),
    obstacleRight: Color(0xFF59342F),
  ),
  RoomMap.core => const _RoomPalette(
    leftWall: Color(0xFF251716),
    backWall: Color(0xFF3A201C),
    cornice: Color(0xFF9A4633),
    tileA: Color(0xFF2B1B19),
    tileB: Color(0xFF3B2420),
    obstacleTop: Color(0xFFE6AC68),
    obstacleLeft: Color(0xFFAA5940),
    obstacleRight: Color(0xFF67382F),
  ),
};

/// One isometric room, drawn with flat polygons (3 tones per object, no
/// textures, no shaders). All state lives in [scene].
class RoomGame extends FlameGame {
  RoomGame(this.scene)
    : super(
        camera: CameraComponent.withFixedResolution(
          width: Iso.canvas.width,
          height: Iso.canvas.height,
        ),
      );

  final RoomScene scene;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    final sheet = await PlayerSheet.load(images, activeCharacter);
    world.add(
      GlitchLayer(scene)..addAll([
        _Shell(scene),
        _WallTexts(scene),
        _Highlights(scene),
        _Door(scene),
        _Crack(scene),
        _Secret(scene),
        _Lamp(scene),
        _Player(scene, sheet),
        _Cabinet(scene),
        _FloorKey(scene),
      ]),
    );
  }
}

/// Renders the room normally, then — when glitching — re-draws it as a red
/// ghost offset by −3px plus 2–4 horizontal slices shifted sideways.
class GlitchLayer extends PositionComponent {
  GlitchLayer(this.scene)
    : super(size: Vector2(Iso.canvas.width, Iso.canvas.height));
  final RoomScene scene;

  static const List<Slice> _light = [
    (y: 172, h: 8, dx: -7),
    (y: 262, h: 10, dx: 5),
  ];
  static const List<Slice> _heavy = [
    (y: 112, h: 12, dx: 9),
    (y: 178, h: 6, dx: -14),
    (y: 236, h: 16, dx: 6),
    (y: 286, h: 5, dx: -9),
  ];
  static const _red = ColorFilter.matrix([
    1.6, 0, 0, 0, 0, //
    0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  void renderTree(Canvas canvas) {
    // Live rooms are driven by the GlitchDirector; static rooms by `glitch`.
    final fx = scene.fx;
    final List<Slice> slices;
    final double ghostDx, ghostOpacity;
    if (fx != null) {
      slices = fx.slices;
      ghostDx = fx.ghostDx;
      ghostOpacity = fx.ghostOpacity;
    } else {
      slices = switch (scene.glitch) {
        0 => const [],
        1 => _light,
        _ => _heavy,
      };
      ghostDx = -3;
      ghostOpacity = switch (scene.glitch) {
        0 => 0,
        1 => .18,
        _ => .32,
      };
    }
    if (slices.isEmpty && ghostOpacity == 0) return super.renderTree(canvas);

    final rec = PictureRecorder();
    super.renderTree(Canvas(rec));
    final pic = rec.endRecording();
    canvas.drawPicture(pic);

    if (ghostOpacity > 0) {
      final ghost = Paint()
        ..colorFilter = _red
        ..blendMode = BlendMode.screen
        ..color = _a(const Color(0xFF000000), ghostOpacity);
      canvas
        ..saveLayer(null, ghost)
        ..translate(ghostDx, 0)
        ..drawPicture(pic)
        ..restore();
    }

    for (final sl in slices) {
      canvas
        ..save()
        ..translate(sl.dx, 0)
        ..clipRect(Rect.fromLTWH(0, sl.y, Iso.canvas.width, sl.h))
        ..drawPicture(pic)
        ..restore();
    }
    pic.dispose();
  }
}

abstract class _Piece extends PositionComponent {
  _Piece(this.scene, int priority) : super(priority: priority);
  final RoomScene scene;
}

/// Floor slab, walls, cornice, floor tiles and the floor light pool.
/// Also the tap target for walking.
class _Shell extends _Piece with TapCallbacks {
  _Shell(RoomScene s) : super(s, 0);

  static const n = 6.0, wh = Iso.wallHeight, t = .22;

  @override
  bool containsLocalPoint(Vector2 point) {
    if (scene.onTile == null) return false;
    final (i, j) = Iso.tileAt(Offset(point.x, point.y));
    return i >= 0 && j >= 0 && i < n && j < n;
  }

  @override
  void onTapUp(TapUpEvent event) {
    final (i, j) = Iso.tileAt(event.localPosition.toOffset());
    scene.onTile?.call(Tile(i.floor(), j.floor()));
  }

  void _wall(Canvas c, List<Offset> pts, Color base) {
    final path = Iso.poly(pts);
    c.drawPath(path, _fill(base));
    final b = Iso.bounds(pts);
    c.drawPath(
      path,
      Paint()
        ..shader = Gradient.linear(b.bottomCenter, b.topCenter, [
          _a(C.ink, .07),
          _a(C.ink, 0),
        ]),
    );
  }

  @override
  void render(Canvas c) {
    final palette = _paletteFor(scene.map);
    c.drawPath(
      Iso.poly([_p(n, 0), _p(n, n), _p(n, n, -10), _p(n, 0, -10)]),
      _fill(const Color(0xFF111113)),
    );
    c.drawPath(
      Iso.poly([_p(0, n), _p(n, n), _p(n, n, -10), _p(0, n, -10)]),
      _fill(const Color(0xFF0D0D0F)),
    );

    if (!scene.noWalls) {
      _wall(c, [
        _p(0, 0),
        _p(0, n),
        _p(0, n, wh),
        _p(0, 0, wh),
      ], palette.leftWall);
      _wall(c, [
        _p(0, 0),
        _p(n, 0),
        _p(n, 0, wh),
        _p(0, 0, wh),
      ], palette.backWall);
      final cornice = palette.cornice;
      c.drawPath(
        Iso.poly([_p(-t, -t, wh), _p(-t, n, wh), _p(0, n, wh), _p(0, 0, wh)]),
        _fill(cornice),
      );
      c.drawPath(
        Iso.poly([_p(-t, -t, wh), _p(n, -t, wh), _p(n, 0, wh), _p(0, 0, wh)]),
        _fill(cornice),
      );
      c.drawPath(
        Iso.poly([_p(-t, n), _p(0, n), _p(0, n, wh), _p(-t, n, wh)]),
        _fill(const Color(0xFF121214)),
      );
      c.drawPath(
        Iso.poly([_p(n, -t), _p(n, 0), _p(n, 0, wh), _p(n, -t, wh)]),
        _fill(const Color(0xFF19191C)),
      );
    }

    final line = _stroke(const Color(0xFF242427), .6);
    for (var j = 0; j < n; j++) {
      for (var i = 0; i < n; i++) {
        final tile = Iso.poly([
          _p(i + 0.0, j + 0.0),
          _p(i + 1.0, j + 0.0),
          _p(i + 1.0, j + 1.0),
          _p(i + 0.0, j + 1.0),
        ]);
        c.drawPath(tile, _fill((i + j).isOdd ? palette.tileB : palette.tileA));
        c.drawPath(tile, line);
      }
    }

    for (final obstacle in scene.obstacles) {
      _drawObstacle(c, obstacle, palette);
    }

    final fc = _p(1.4, 1.4);
    c.drawPath(
      Iso.poly([_p(0, 0), _p(n, 0), _p(n, n), _p(0, n)]),
      Paint()
        ..shader = Gradient.radial(
          fc,
          210,
          [
            _a(C.ink, scene.secret ? .16 : .1),
            _a(C.ink, .025),
            _a(const Color(0xFF000000), .4),
          ],
          [0, .55, 1],
        ),
    );

    if (!scene.noWalls) {
      c.drawPath(
        Path()
          ..moveTo(_p(0, n).dx, _p(0, n).dy)
          ..lineTo(_p(0, 0).dx, _p(0, 0).dy)
          ..lineTo(_p(n, 0).dx, _p(n, 0).dy),
        _stroke(C.ink, 1, .08),
      );
    }
  }

  void _drawObstacle(Canvas canvas, Tile tile, _RoomPalette palette) {
    final i = tile.i.toDouble(), j = tile.j.toDouble();
    const height = 24.0;
    final top = [
      _p(i + .5, j + .08, height),
      _p(i + .92, j + .5, height),
      _p(i + .5, j + .92, height),
      _p(i + .08, j + .5, height),
    ];
    final base = [
      _p(i + .5, j + .08),
      _p(i + .92, j + .5),
      _p(i + .5, j + .92),
      _p(i + .08, j + .5),
    ];
    canvas
      ..drawPath(
        Iso.poly([top[3], top[2], base[2], base[3]]),
        _fill(palette.obstacleLeft),
      )
      ..drawPath(
        Iso.poly([top[2], top[1], base[1], base[2]]),
        _fill(palette.obstacleRight),
      )
      ..drawPath(Iso.poly(top), _fill(palette.obstacleTop))
      ..drawPath(Iso.poly(top), _stroke(C.ink, .7, .28));
  }
}

class _WallTexts extends _Piece {
  _WallTexts(RoomScene s) : super(s, 1);

  final _cache = <WallText, TextPainter>{};

  @override
  void render(Canvas c) {
    for (final w in scene.wallText) {
      final tp = _cache.putIfAbsent(
        w,
        () => TextPainter(
          text: TextSpan(
            text: w.text,
            style: TextStyle(
              fontFamily: kMono,
              fontSize: w.size,
              letterSpacing: 1,
              color: _a(w.color, w.opacity),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
      );
      final right = w.wall == 'r';
      final o = right ? _p(w.at, 0, w.z) : _p(0, w.at, w.z);
      // Skew the text onto the wall plane: matrix(1, ±.5, 0, 1, x, y).
      final m = Float64List.fromList([
        1, right ? .5 : -.5, 0, 0, //
        0, 1, 0, 0,
        0, 0, 1, 0,
        o.dx, o.dy, 0, 1,
      ]);
      c
        ..save()
        ..transform(m);
      tp.paint(
        c,
        Offset(0, -tp.computeDistanceToActualBaseline(TextBaseline.alphabetic)),
      );
      c.restore();
    }
  }
}

class _Highlights extends _Piece {
  _Highlights(RoomScene s) : super(s, 2);

  @override
  void render(Canvas c) {
    for (final h in scene.highlights) {
      final i = h.tile.i.toDouble(), j = h.tile.j.toDouble();
      final pts = [
        _p(i + .12, j + .12),
        _p(i + .88, j + .12),
        _p(i + .88, j + .88),
        _p(i + .12, j + .88),
      ];
      c.drawPath(Iso.poly(pts), _fill(h.color, .1));
      _dashed(c, [...pts, pts.first], _stroke(h.color, 1.2), 3, 3);
    }
  }
}

void _dashed(Canvas c, List<Offset> pts, Paint paint, double on, double off) {
  var draw = true, left = on;
  for (var k = 0; k < pts.length - 1; k++) {
    var a = pts[k];
    final b = pts[k + 1];
    var seg = (b - a).distance;
    final dir = (b - a) / seg;
    while (seg > 0) {
      final step = math.min(left, seg);
      final e = a + dir * step;
      if (draw) c.drawLine(a, e, paint);
      a = e;
      seg -= step;
      left -= step;
      if (left <= 0) {
        draw = !draw;
        left = draw ? on : off;
      }
    }
  }
}

class _Door extends _Piece with TapCallbacks {
  _Door(RoomScene s) : super(s, 3);

  static const d0 = 3.6, d1 = 4.9, dh = 70.0;

  List<Offset> get _hit => [
    _p(d0 - .35, 0),
    _p(d1 + .35, 0),
    _p(d1 + .35, 0, dh + 18),
    _p(d0 - .35, 0, dh + 18),
  ];

  @override
  bool containsLocalPoint(Vector2 point) =>
      !scene.noDoor &&
      scene.onDoor != null &&
      Iso.poly(_hit).contains(point.toOffset());

  @override
  void onTapUp(TapUpEvent event) => scene.onDoor?.call();

  @override
  void render(Canvas c) {
    if (scene.noDoor) return;
    final open = scene.doorOpen;
    if (open) {
      final a = _p(4.25, 0), b = _p(4.25, 2.6);
      c.drawPath(
        Iso.poly([_p(d0, 0), _p(d1, 0), _p(d1 + .3, 2.6), _p(d0 - .3, 2.6)]),
        Paint()..shader = Gradient.linear(a, b, [_a(C.ink, .32), _a(C.ink, 0)]),
      );
      c.drawPath(Iso.poly(_hit), _fill(C.ink, .06));
    }
    c.drawPath(
      Iso.poly([
        _p(d0 - .12, 0),
        _p(d1 + .12, 0),
        _p(d1 + .12, 0, dh + 6),
        _p(d0 - .12, 0, dh + 6),
      ]),
      _fill(const Color(0xFF2A2A2E)),
    );
    c.drawPath(
      Iso.poly([_p(d0, 0), _p(d1, 0), _p(d1, 0, dh), _p(d0, 0, dh)]),
      _fill(open ? C.ink : const Color(0xFF111113)),
    );
    if (!open) {
      c.drawCircle(_p(d1 - .16, 0, 34), 1.8, _fill(C.dim));
      c.drawLine(
        _p(d0, 0, 1.2),
        _p(d1, 0, 1.2),
        scene.doorHint
            ? _stroke(scene.doorColor, 1.6, .9)
            : _stroke(C.ink, 1.6, .28),
      );
    }
  }
}

class _Crack extends _Piece with TapCallbacks {
  _Crack(RoomScene s) : super(s, 4);

  static final _pts = [
    _p(0, 1.62, 96),
    _p(0, 1.8, 80),
    _p(0, 1.52, 64),
    _p(0, 1.88, 46),
    _p(0, 1.6, 28),
    _p(0, 1.76, 10),
  ];
  static final _hit = Iso.poly([
    _p(0, 1.1),
    _p(0, 2.2),
    _p(0, 2.2, 104),
    _p(0, 1.1, 104),
  ]);

  @override
  bool containsLocalPoint(Vector2 point) =>
      scene.crack && scene.onCrack != null && _hit.contains(point.toOffset());

  @override
  void onTapUp(TapUpEvent event) => scene.onCrack?.call();

  @override
  void render(Canvas c) {
    if (!scene.crack) return;
    final path = Path()..addPolygon(_pts, false);
    c
      ..drawPath(path, _stroke(C.ink, 5, .1))
      ..drawPath(path, _stroke(C.ink, 1, .6));
  }
}

class _Secret extends _Piece {
  _Secret(RoomScene s) : super(s, 5);

  @override
  void render(Canvas c) {
    if (!scene.secret) return;
    c.drawPath(
      Iso.poly([_p(0, 1.1), _p(0, 2.2), _p(2.4, 2.4), _p(2.4, .9)]),
      Paint()
        ..shader = Gradient.linear(_p(0, 1.6), _p(2.4, 1.6), [
          _a(C.ink, .3),
          _a(C.ink, 0),
        ]),
    );
    c.drawPath(
      Iso.poly([_p(0, .85), _p(0, 2.45), _p(0, 2.45, 90), _p(0, .85, 90)]),
      _fill(C.ink, .07),
    );
    c.drawPath(
      Iso.poly([_p(0, 1.1), _p(0, 2.2), _p(0, 2.2, 74), _p(0, 1.1, 74)]),
      _fill(C.ink),
    );
  }
}

class _Lamp extends _Piece {
  _Lamp(RoomScene s) : super(s, 6);

  @override
  void render(Canvas c) {
    if (scene.noLamp) return;
    final lp = _p(.5, .5, 84), b = _p(.5, .5);
    final gc = lp.translate(0, 10);
    c.drawCircle(
      gc,
      46,
      Paint()..shader = Gradient.radial(gc, 46, [_a(C.ink, .3), _a(C.ink, 0)]),
    );
    c.drawOval(
      Rect.fromCenter(center: b, width: 14, height: 7),
      _fill(const Color(0xFF2A2A2E)),
    );
    c.drawLine(b, lp, _stroke(const Color(0xFF3A3A3E), 1.5));
    c.drawPath(
      Iso.poly([
        lp.translate(-11, 10),
        lp.translate(11, 10),
        lp.translate(6, -2),
        lp.translate(-6, -2),
      ]),
      _fill(const Color(0xFF2E2E32)),
    );
    c.drawLine(
      lp.translate(-11, 10),
      lp.translate(11, 10),
      _stroke(C.ink, 1, .7),
    );
  }
}

/// The player, played from the sprite sheet: walks tile→tile in 170ms with
/// the walk cycle, turns to face where it goes, and breathes when idle.
class _Player extends _Piece {
  _Player(RoomScene s, this.sheet) : super(s, 10);

  final PlayerSheet sheet;
  static const stepTime = .17;

  Offset? _pos; // fractional tile coords
  Facing _facing = Facing.se;
  Pose _pose = Pose.idle;
  double _animMs = 0, _stillFor = 0;
  final _paint = Paint()..filterQuality = FilterQuality.medium;

  @override
  void update(double dt) {
    final t = scene.player;
    if (t == null) {
      _pos = null;
      return;
    }
    final target = Offset(t.i.toDouble(), t.j.toDouble());
    final cur = _pos;
    if (cur == null || (target - cur).distance > 1.5) {
      // Teleport (stage change / static room): face the scene's direction.
      _pos = target;
      _facing = scene.facing;
      _stillFor = 1;
    } else {
      final d = target - cur, dist = d.distance, step = dt / stepTime;
      if (dist > 1e-6) {
        _facing = Facing.of(d.dx, d.dy) ?? _facing;
        _stillFor = 0;
      } else {
        _stillFor += dt;
      }
      _pos = dist <= step ? target : cur + d / dist * step;
    }
    // A short grace period keeps the walk cycle going between tiles.
    final pose = _stillFor < .06 ? Pose.walk : Pose.idle;
    if (pose != _pose) {
      _pose = pose;
      _animMs = 0;
    }
    _animMs += dt * 1000;
    // Behind the cabinet only when standing against the left wall's back half.
    priority = t.i == 0 && t.j < 3 ? 7 : 10;
  }

  @override
  void render(Canvas c) {
    final pos = _pos;
    if (pos == null) return;
    sheet.draw(
      c,
      _p(pos.dx + .5, pos.dy + .5),
      _facing,
      _pose,
      _animMs,
      _paint,
    );
  }
}

class _Cabinet extends _Piece with TapCallbacks {
  _Cabinet(RoomScene s) : super(s, 8);

  static const i0 = .02, i1 = .95, j0 = 3.08, j1 = 4.35, z = 42.0;
  static final _hit = Iso.poly([
    _p(i0, j0, z),
    _p(i1, j0, z),
    _p(i1, j0),
    _p(i1, j1),
    _p(i0, j1),
    _p(i0, j1, z),
  ]);

  @override
  bool containsLocalPoint(Vector2 point) =>
      !scene.noCabinet &&
      scene.onCabinet != null &&
      _hit.contains(point.toOffset());

  @override
  void onTapUp(TapUpEvent event) => scene.onCabinet?.call();

  void _handle(Canvas c, double zz, double ii) =>
      c.drawLine(_p(ii, 3.55, zz), _p(ii, 3.88, zz), _stroke(C.dim, 1.4));

  @override
  void render(Canvas c) {
    if (scene.noCabinet) return;
    c.drawPath(
      Iso.poly([_p(i0, j0, z), _p(i1, j0, z), _p(i1, j1, z), _p(i0, j1, z)]),
      _fill(const Color(0xFF34343A)),
    );
    c.drawPath(
      Iso.poly([_p(i1, j0), _p(i1, j1), _p(i1, j1, z), _p(i1, j0, z)]),
      _fill(const Color(0xFF26262A)),
    );
    c.drawPath(
      Iso.poly([_p(i0, j1), _p(i1, j1), _p(i1, j1, z), _p(i0, j1, z)]),
      _fill(const Color(0xFF1E1E21)),
    );
    c.drawLine(
      _p(i1, j0 + .06, 21),
      _p(i1, j1 - .06, 21),
      _stroke(const Color(0xFF111113), 1.2),
    );
    _handle(c, 10, i1);
    if (scene.drawerOpen) {
      const k0 = i1, k1 = i1 + .55, m0 = 3.2, m1 = 4.23, z0 = 23.0, z1 = 37.0;
      final top = Iso.poly([
        _p(k0, m0, z1),
        _p(k1, m0, z1),
        _p(k1, m1, z1),
        _p(k0, m1, z1),
      ]);
      c
        ..drawPath(top, _fill(const Color(0xFF08080A)))
        ..drawPath(top, _stroke(const Color(0xFF3A3A3E), .8));
      c.drawPath(
        Iso.poly([
          _p(k1, m0, z0),
          _p(k1, m1, z0),
          _p(k1, m1, z1),
          _p(k1, m0, z1),
        ]),
        _fill(const Color(0xFF2E2E33)),
      );
      c.drawPath(
        Iso.poly([
          _p(k0, m1, z0),
          _p(k1, m1, z0),
          _p(k1, m1, z1),
          _p(k0, m1, z1),
        ]),
        _fill(const Color(0xFF232327)),
      );
      _handle(c, 30, k1);
    } else {
      _handle(c, 31, i1);
    }
  }
}

class _FloorKey extends _Piece {
  _FloorKey(RoomScene s) : super(s, 9);

  @override
  void render(Canvas c) {
    if (!scene.keyOnFloor) return;
    final k = _p(5.5, 5.5);
    final ink = _stroke(C.ink, 1.4, .75);
    c
      ..save()
      ..translate(k.dx, k.dy - 2)
      ..drawCircle(const Offset(-4, 0), 3.2, ink)
      ..drawLine(const Offset(-.8, 0), const Offset(8, 0), ink)
      ..drawLine(const Offset(5.5, 0), const Offset(5.5, 3), ink)
      ..restore();
  }
}
