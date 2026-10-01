// Renders the player sprite sheets from lib/room/character.dart.
//
//   flutter test tool/generate_sprites.dart
//
// Writes assets/images/sprites/player_<style>.png (+ player.json atlas).
// Layout per sheet: one row per facing (se, sw, ne, nw); columns are the idle
// frames followed by the walk frames. Frames are drawn at 4× the in-game size
// so they stay sharp on 3× phones; the feet sit at `anchor`.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dont_trust_the_game/room/character.dart';
import 'package:flutter_test/flutter_test.dart';

const scale = 4.0;
const outDir = 'assets/images/sprites';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate player sprite sheets', () async {
    Directory(outDir).createSync(recursive: true);
    final cols = Pose.idle.frames + Pose.walk.frames;
    final fw = frameSize.width * scale, fh = frameSize.height * scale;

    for (final style in CharacterStyle.values) {
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec);
      for (final (row, f) in Facing.values.indexed) {
        var col = 0;
        for (final pose in Pose.values) {
          for (var k = 0; k < pose.frames; k++, col++) {
            c
              ..save()
              ..translate(
                col * fw + frameAnchor.dx * scale,
                row * fh + frameAnchor.dy * scale,
              )
              ..scale(scale);
            paintCharacter(c, style, f, pose, k / pose.frames);
            c.restore();
          }
        }
      }
      final img = await rec.endRecording().toImage(
        (cols * fw).round(),
        (4 * fh).round(),
      );
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$outDir/player_${style.name}.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    }

    var start = 0;
    final atlas = {
      'frameWidth': fw,
      'frameHeight': fh,
      'scale': scale,
      'anchor': [frameAnchor.dx * scale, frameAnchor.dy * scale],
      'rows': [for (final f in Facing.values) f.name],
      'animations': {
        for (final pose in Pose.values)
          pose.name: {
            'start': (start, start += pose.frames).$1,
            'frames': pose.frames,
            'frameMs': pose.frameMs,
          },
      },
      'sheets': {
        for (final s in CharacterStyle.values) s.name: 'player_${s.name}.png',
      },
    };
    File('$outDir/player.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(atlas)}\n',
    );
  });
}
