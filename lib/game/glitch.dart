import 'dart:math' as math;
import 'dart:ui';

/// One horizontal slice of the room, re-drawn shifted sideways.
typedef Slice = ({double y, double h, double dx});

/// What the room's glitch layer draws this frame.
class GlitchFx {
  List<Slice> slices = const [];
  double ghostDx = -3;
  double ghostOpacity = 0;

  bool get active => ghostOpacity > 0 || slices.isNotEmpty;
}

/// How unstable the game currently allows itself to look.
enum Unease {
  /// 01 TRUST, 05 TRUTH: perfectly still.
  none(0, 0, 0, 0),

  /// 02 after "I LIED.": rare, tiny bursts. The pause button flickers once.
  hint(6000, 10000, 90, 140),

  /// 04 WATCHING: steady ghost, a burst every few seconds.
  watching(2800, 5600, 120, 240),

  /// 03 UI GLITCH: the game can't hold its UI together.
  broken(1600, 3800, 150, 320);

  const Unease(this.gapMin, this.gapMax, this.burstMin, this.burstMax);
  final int gapMin, gapMax, burstMin, burstMax;
}

/// Schedules glitch bursts on the game clock and exposes what the room and
/// the UI should show. Deterministic for a given [math.Random] seed.
class GlitchDirector {
  GlitchDirector([math.Random? random]) : _rnd = random ?? math.Random();

  final math.Random _rnd;
  final GlitchFx fx = GlitchFx();

  Unease _unease = Unease.none;
  int _untilNext = 0, _burstLeft = 0, _jitterMs = 0;

  /// Changes every burst; UI uses it to pick which labels flicker.
  int seed = 0;
  Offset jitter = Offset.zero;

  Unease get unease => _unease;
  bool get bursting => _burstLeft > 0;

  set unease(Unease u) {
    if (u == _unease) return;
    _unease = u;
    _burstLeft = 0;
    _scheduleNext();
    _rest();
  }

  /// Forces an immediate burst (stage transitions). Returns nothing visible
  /// when [heavy] is false and the game is calm.
  void burst({int ms = 260, bool heavy = true}) {
    _burstLeft = ms;
    _startBurst(heavy: heavy);
  }

  /// Advances the clock. Returns true when something visible changed.
  bool tick(int ms) {
    if (_burstLeft > 0) {
      _burstLeft -= ms;
      if (_burstLeft <= 0) {
        _scheduleNext();
        _rest();
        return true;
      }
      _jitterMs += ms;
      if (_jitterMs >= 50) {
        _jitterMs = 0;
        _reroll();
        return true;
      }
      return false;
    }
    if (_unease == Unease.none) return false;
    _untilNext -= ms;
    if (_untilNext > 0) return false;
    _burstLeft = _range(_unease.burstMin, _unease.burstMax);
    _startBurst(heavy: _unease == Unease.broken);
    return true;
  }

  /// [alt] while this burst "chose" to flicker label [k], else [normal].
  String flicker(String normal, String alt, {int k = 0, double chance = .6}) {
    if (!bursting) return normal;
    final r = math.Random(seed * 31 + k).nextDouble();
    return r < chance ? alt : normal;
  }

  /// Replaces a few characters with glitch glyphs during a burst.
  String scramble(String s, {double amount = .12}) {
    if (!bursting || s.isEmpty) return s;
    const glyphs = '#%01/\\_=+';
    final r = math.Random(seed);
    return String.fromCharCodes(s.codeUnits.map((c) =>
        c != 32 && r.nextDouble() < amount
            ? glyphs.codeUnitAt(r.nextInt(glyphs.length))
            : c));
  }

  // ------------------------------------------------------------ internals

  bool _heavy = false;

  void _startBurst({required bool heavy}) {
    _heavy = heavy;
    seed = _rnd.nextInt(1 << 30);
    _jitterMs = 0;
    _reroll();
  }

  void _reroll() {
    final heavy = _heavy;
    final n = heavy ? 3 + _rnd.nextInt(2) : 1 + _rnd.nextInt(2);
    fx.slices = [
      for (var k = 0; k < n; k++)
        (
          y: 90 + _rnd.nextDouble() * 210,
          h: 4 + _rnd.nextDouble() * (heavy ? 14 : 8),
          dx: (_rnd.nextBool() ? 1 : -1) * (4 + _rnd.nextDouble() * (heavy ? 12 : 6)),
        ),
    ];
    fx.ghostDx = -(3 + _rnd.nextDouble() * (heavy ? 5 : 2));
    fx.ghostOpacity = heavy ? .32 : .22;
    final j = heavy ? 3.0 : 1.5;
    jitter = Offset((_rnd.nextDouble() * 2 - 1) * j, (_rnd.nextDouble() * 2 - 1) * j * .6);
  }

  /// Between bursts: stage 03–04 keep the design's steady light slices + ghost.
  void _rest() {
    jitter = Offset.zero;
    switch (_unease) {
      case Unease.broken || Unease.watching:
        fx
          ..slices = const [(y: 172, h: 8, dx: -7), (y: 262, h: 10, dx: 5)]
          ..ghostDx = -3
          ..ghostOpacity = _unease == Unease.broken ? .18 : .14;
      case Unease.none || Unease.hint:
        fx
          ..slices = const []
          ..ghostOpacity = 0;
    }
  }

  void _scheduleNext() =>
      _untilNext = _range(_unease.gapMin, _unease.gapMax);

  int _range(int a, int b) => a + (b > a ? _rnd.nextInt(b - a) : 0);
}
