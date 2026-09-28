import 'dart:async';

import 'package:flutter/material.dart';

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

  late final Timer _timer;
  int _ms = 0;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      setState(() => _ms += 30);
      if (_ms >= _totalMs + 500) _go();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _go() {
    if (_left) return;
    _left = true;
    _timer.cancel();
    Navigator.of(context).pushReplacement(fadeRoute(const GameScreen()));
  }

  String _typed(String s, int startMs) =>
      s.substring(0, ((_ms - startMs) / 30).clamp(0, s.length).floor());

  @override
  Widget build(BuildContext context) {
    final progress = (_ms / _totalMs).clamp(0.0, 1.0);
    const helloAt = 1900, helpAt = helloAt + 450;
    final hello = _typed(_hello, helloAt), help = _typed(_help, helpAt);
    final cursorOnHelp = _ms >= helpAt;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _go,
        child: DesignFrame(
          background: Colors.black,
          child: Stack(children: [
            Positioned(
              top: 28,
              left: 28,
              child: Text('DTTG // BOOT 0.9.3', style: mono(10, color: C.muted, tracking: .2)),
            ),
            Positioned(
              top: 150,
              left: 28,
              right: 28,
              child: Column(children: [
                for (var k = 0; k < _checks.length; k++)
                  if (_ms >= k * 380)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_checks[k], style: mono(12, color: C.dim, tracking: .06)),
                          if (_ms >= k * 380 + 260)
                            Text('OK', style: mono(12, color: C.safe, tracking: .06)),
                        ],
                      ),
                    ),
              ]),
            ),
            Positioned(
              top: 340,
              left: 28,
              right: 28,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_ms >= helloAt)
                    Text.rich(TextSpan(children: [
                      TextSpan(text: hello),
                      if (!cursorOnHelp) BlinkCursor.span(28, C.ink),
                    ]), style: _big),
                  const SizedBox(height: 8),
                  if (cursorOnHelp)
                    Text.rich(TextSpan(children: [
                      TextSpan(text: help),
                      BlinkCursor.span(28, C.ink),
                    ]), style: _big),
                ],
              ),
            ),
            Positioned(
              left: 28,
              right: 28,
              bottom: 46,
              child: Column(children: [
                SizedBox(
                  height: 1,
                  child: Stack(children: [
                    const Positioned.fill(child: ColoredBox(color: C.terminalTop)),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: const ColoredBox(color: C.ink, child: SizedBox.expand()),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('LOADING ${(progress * 100).round()}%',
                        style: mono(10, color: C.muted, tracking: .2)),
                    Text('TAP TO SKIP', style: mono(10, color: C.muted, tracking: .2)),
                  ],
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  static final _big = mono(28, weight: FontWeight.w500, height: 1.2);
}
