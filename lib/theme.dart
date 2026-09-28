import 'package:flutter/widgets.dart';

/// Palette from the design sheet ("WARNA") plus the in-between greys the
/// screens use for borders and secondary text.
abstract final class C {
  static const void_ = Color(0xFF0B0B0C);
  static const page = Color(0xFF050506);
  static const panel = Color(0xFF0D0D0F);
  static const sheet = Color(0xFF111113);
  static const wall = Color(0xFF1F1F22);
  static const line = Color(0xFF2A2A2D);
  static const ink = Color(0xFFEDEAE3);
  static const warn = Color(0xFFE5484D);
  static const safe = Color(0xFF5BBF7A);

  static const muted = Color(0xFF808086);
  static const dim = Color(0xFF8A8A8E);
  static const rule = Color(0xFF1E1E21);
  static const divider = Color(0xFF1C1C1F);
  static const border = Color(0xFF2E2E32);
  static const borderHi = Color(0xFF333337);
  static const borderBtn = Color(0xFF3A3A3E);
  static const terminalTop = Color(0xFF222225);
}

const kMono = 'IBMPlexMono';
const kSerif = 'InstrumentSerif';

/// Monospace "system" voice. [tracking] is CSS letter-spacing in em.
TextStyle mono(double size,
        {Color color = C.ink,
        double tracking = 0,
        FontWeight weight = FontWeight.w400,
        double? height,
        List<Shadow>? shadows}) =>
    TextStyle(
      fontFamily: kMono,
      fontSize: size,
      color: color,
      letterSpacing: size * tracking,
      fontWeight: weight,
      height: height,
      shadows: shadows,
    );

/// Serif italic — "the game's real voice", introduced in stage 04.
TextStyle serif(double size, {Color color = C.ink, double? height}) =>
    TextStyle(
      fontFamily: kSerif,
      fontStyle: FontStyle.italic,
      fontSize: size,
      color: color,
      height: height,
    );
