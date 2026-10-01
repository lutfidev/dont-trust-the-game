import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/cues.dart';
import '../audio/game_audio.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'game_screen.dart';

/// 02 — Boot / intro. Friendly and helpful; green only as "OK".
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  static const _checks = [
    '> INITIALIZING',
    '> LOADING ROOM_01',
    '> CALIBRATING TRUST',
    '> PLAYER DETECTED',
  ];
  static const _hello = 'HELLO.';
  static const _help = 'I WILL HELP YOU.';
  static const _totalMs = 5200;
  static const _helloAt = 1900, _helpAt = _helloAt + 450;

  late final Timer _timer;
  late final GameAudio _audio = AudioScope.of(context);
  int _ms = 0;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _audio.mood(Mood.silence); // the menu lullaby fades; only the system speaks
    _cues(-1, 0);
    _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      setState(() => _ms += 30);
      _cues(_ms - 30, _ms);
      if (_ms >= _totalMs + 500) _go();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    if (!_left) _audio.mood(Mood.trust); // backed out to the menu
    super.dispose();
  }

  /// Sounds for everything that appears after [from] up to and including [to].
  void _cues(int from, int to) {
    bool at(int ms) => from < ms && ms <= to;
    for (var k = 0; k < _checks.length; k++) {
      if (at(k * 380)) _audio.play(Sfx.bootTick);
      if (at(k * 380 + 260)) _audio.play(Sfx.bootOk);
    }
    if (at(_helloAt)) _audio.play(Sfx.hello);
    for (final (s, start) in [(_hello, _helloAt), (_help, _helpAt)]) {
      final now = _typedLen(s, start, to);
      if (now > _typedLen(s, start, from) && s[now - 1] != ' ') {
        _audio.play(Sfx.type);
      }
    }
  }

  static int _typedLen(String s, int startMs, int ms) =>
      ((ms - startMs) / 30).clamp(0, s.length).floor();

  void _go() {
    if (_left) return;
    _left = true;
    _timer.cancel();
    Navigator.of(context).pushReplacement(fadeRoute(const GameScreen()));
  }

  String _typed(String s, int startMs) =>
      s.substring(0, _typedLen(s, startMs, _ms));

  @override
  Widget build(BuildContext context) {
    final progress = (_ms / _totalMs).clamp(0.0, 1.0);
    final hello = _typed(_hello, _helloAt), help = _typed(_help, _helpAt);
    final cursorOnHelp = _ms >= _helpAt;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _go,
        child: DesignFrame(
          background: Colors.black,
          child: Stack(
            children: [
              Positioned(
                top: 28,
                left: 28,
                child: Text(
                  'DTTG // BOOT 0.9.3',
                  style: mono(10, color: C.muted, tracking: .2),
                ),
              ),
              Positioned(
                top: 150,
                left: 28,
                right: 28,
                child: Column(
                  children: [
                    for (var k = 0; k < _checks.length; k++)
                      if (_ms >= k * 380)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _checks[k],
                                style: mono(12, color: C.dim, tracking: .06),
                              ),
                              if (_ms >= k * 380 + 260)
                                Text(
                                  'OK',
                                  style: mono(12, color: C.safe, tracking: .06),
                                ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
              Positioned(
                top: 340,
                left: 28,
                right: 28,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_ms >= _helloAt)
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: hello),
                            if (!cursorOnHelp) BlinkCursor.span(28, C.ink),
                          ],
                        ),
                        style: _big,
                      ),
                    const SizedBox(height: 8),
                    if (cursorOnHelp)
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: help),
                            BlinkCursor.span(28, C.ink),
                          ],
                        ),
                        style: _big,
                      ),
                  ],
                ),
              ),
              Positioned(
                left: 28,
                right: 28,
                bottom: 46,
                child: Column(
                  children: [
                    SizedBox(
                      height: 1,
                      child: Stack(
                        children: [
                          const Positioned.fill(
                            child: ColoredBox(color: C.terminalTop),
                          ),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress,
                            child: const ColoredBox(
                              color: C.ink,
                              child: SizedBox.expand(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'LOADING ${(progress * 100).round()}%',
                          style: mono(10, color: C.muted, tracking: .2),
                        ),
                        Text(
                          'TAP TO SKIP',
                          style: mono(10, color: C.muted, tracking: .2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static final _big = mono(28, weight: FontWeight.w500, height: 1.2);
}
