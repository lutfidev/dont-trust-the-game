import 'dart:convert';
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'character.dart';

/// A player sprite sheet plus its atlas (`assets/images/sprites/player.json`).
///
/// Rows are facings, columns are pose frames. Everything about the layout
/// comes from the JSON, so artists can replace the PNGs (and change frame
/// counts or timing) without touching code.
class PlayerSheet {
  PlayerSheet._(this.image, this._atlas);

  final Image image;
  final Map<String, dynamic> _atlas;

  static const atlasPath = 'assets/images/sprites/player.json';

  static Future<PlayerSheet> load(Images images, CharacterStyle style) async {
    final atlas = jsonDecode(
      await rootBundle.loadString(atlasPath),
    ) as Map<String, dynamic>;
    final file =
        (atlas['sheets'] as Map<String, dynamic>)[style.name] as String;
    return PlayerSheet._(await images.load('sprites/$file'), atlas);
  }

  double get _scale => (_atlas['scale'] as num).toDouble();
  Size get frame => Size(
    (_atlas['frameWidth'] as num).toDouble(),
    (_atlas['frameHeight'] as num).toDouble(),
  );
  Offset get anchor {
    final a = _atlas['anchor'] as List;
    return Offset((a[0] as num).toDouble(), (a[1] as num).toDouble());
  }

  ({int start, int frames, int frameMs}) animation(Pose pose) {
    final a =
        (_atlas['animations'] as Map<String, dynamic>)[pose.name]
            as Map<String, dynamic>;
    return (
      start: a['start'] as int,
      frames: a['frames'] as int,
      frameMs: a['frameMs'] as int,
    );
  }

  int row(Facing f) => (_atlas['rows'] as List).indexOf(f.name);

  /// Draws [pose] frame at [ms] into the animation, feet at [feet].
  void draw(
    Canvas c,
    Offset feet,
    Facing f,
    Pose pose,
    double ms,
    Paint paint,
  ) {
    final a = animation(pose);
    final col = a.start + (ms ~/ a.frameMs) % a.frames;
    final fr = frame, s = _scale;
    final src = Rect.fromLTWH(
      col * fr.width,
      row(f) * fr.height,
      fr.width,
      fr.height,
    );
    final dst = Rect.fromLTWH(
      feet.dx - anchor.dx / s,
      feet.dy - anchor.dy / s,
      fr.width / s,
      fr.height / s,
    );
    c.drawImageRect(image, src, dst, paint);
  }
}
