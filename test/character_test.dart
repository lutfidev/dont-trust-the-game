import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dont_trust_the_game/room/character.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('facing follows the direction of travel', () {
    expect(Facing.of(1, 0), Facing.se); // +i: right-down on screen
    expect(Facing.of(-1, 0), Facing.nw);
    expect(Facing.of(0, 1), Facing.sw); // +j: left-down
    expect(Facing.of(0, -1), Facing.ne);
    expect(Facing.of(0, 0), isNull);
    expect(Facing.se.front && Facing.sw.front, isTrue);
    expect(Facing.ne.front || Facing.nw.front, isFalse);
  });

  test('sprite sheets match the atlas', () {
    final atlas = jsonDecode(File('assets/images/sprites/player.json').readAsStringSync())
        as Map<String, dynamic>;
    final anims = atlas['animations'] as Map<String, dynamic>;
    final cols = anims.values.fold<int>(0, (n, a) => n + (a['frames'] as int));
    final rows = (atlas['rows'] as List).length;
    for (final style in CharacterStyle.values) {
      final file = (atlas['sheets'] as Map<String, dynamic>)[style.name] as String;
      final png = File('assets/images/sprites/$file').readAsBytesSync();
      final header = ByteData.sublistView(png, 16, 24);
      expect(header.getUint32(0), cols * (atlas['frameWidth'] as num), reason: file);
      expect(header.getUint32(4), rows * (atlas['frameHeight'] as num), reason: file);
    }
    expect(atlas['rows'], [for (final f in Facing.values) f.name]);
  });
}
