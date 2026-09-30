import 'dart:io';
import 'dart:typed_data';

import 'package:dont_trust_the_game/audio/cues.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('volume setting maps to gain: mute, 0 dB at 10, 3 dB per step', () {
    expect(volumeGain(0), 0);
    expect(volumeGain(10), 1);
    expect(volumeGain(8), closeTo(.501, .001));
    expect(volumeGain(6), closeTo(.251, .001));
    for (var v = 1; v < 10; v++) {
      expect(volumeGain(v), lessThan(volumeGain(v + 1)));
    }
  });

  test('every sound and music file exists and is declared', () {
    for (final s in Sfx.values) {
      final f = File(s.asset);
      expect(f.existsSync(), isTrue, reason: s.asset);
      // RIFF header: mono, 44.1 kHz, 16-bit.
      final h = ByteData.sublistView(f.readAsBytesSync());
      expect(h.getUint16(22, Endian.little), 1, reason: '${s.asset} channels');
      expect(h.getUint32(24, Endian.little), 44100, reason: '${s.asset} rate');
      expect(h.getUint16(34, Endian.little), 16, reason: '${s.asset} bits');
    }
    for (final m in Mood.values) {
      final a = m.asset;
      if (a != null) expect(File(a).existsSync(), isTrue, reason: a);
    }
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/audio/sfx/'));
    expect(pubspec, contains('- assets/audio/music/'));
  });

  test('only the true ending is a one-shot, and silence has no file', () {
    expect(Mood.silence.asset, isNull);
    expect([for (final m in Mood.values) if (!m.loop) m], [Mood.truthEnd]);
  });
}
