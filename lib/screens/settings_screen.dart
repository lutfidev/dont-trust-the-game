import 'package:flutter/material.dart';

import '../main.dart';
import '../settings.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// 09 — Settings. Everything is normal, except "LET THE GAME HELP YOU",
/// which switches itself back on every time it is turned off.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _resetTaps = 0;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      body: DesignFrame(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  HudButton('[ ← ]', onTap: () => Navigator.of(context).pop()),
                  Text('SETTINGS', style: mono(11, color: C.dim, tracking: .3)),
                ],
              ),
              const SizedBox(height: 34),
              _Row('MUSIC', _Cells(s.music, s.setMusic)),
              _Row('SFX', _Cells(s.sfx, s.setSfx)),
              _Row(
                'TEXT SPEED',
                Row(children: [
                  for (final sp in TextSpeed.values)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: GestureDetector(
                        onTap: () => s.setSpeed(sp),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 9),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              border: Border.all(color: sp == s.speed ? C.ink : C.line)),
                          child: Text(sp.label,
                              style: mono(10,
                                  tracking: .12,
                                  color: sp == s.speed ? C.ink : C.muted)),
                        ),
                      ),
                    ),
                ]),
              ),
              _Row('VIBRATION', _Toggle(s.vibration, s.toggleVibration)),
              _Row('SCREEN SHAKE', _Toggle(s.screenShake, s.toggleShake)),
              _Row(
                'LET THE GAME HELP YOU',
                _Toggle(s.assist, s.toggleAssist),
                sub: Text(s.assistMessage, style: mono(10, color: C.warn, tracking: .14)),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_resetTaps == 1) s.resetProgress();
                      setState(() => _resetTaps = (_resetTaps + 1).clamp(0, 2));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        const ['RESET PROGRESS', 'TAP AGAIN TO RESET', 'PROGRESS RESET.'][_resetTaps],
                        style: mono(10, color: C.warn, tracking: .2),
                      ),
                    ),
                  ),
                  Text('v1.0', style: mono(10, color: C.muted, tracking: .2)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.control, {this.sub});
  final String label;
  final Widget control;
  final Widget? sub;

  @override
  Widget build(BuildContext context) {
    final l = Text(label, style: mono(12, tracking: .16));
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.divider))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: sub == null
                ? l
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [l, const SizedBox(height: 4), SizedBox(height: 13, child: sub)],
                  ),
          ),
          const SizedBox(width: 12),
          control,
        ],
      ),
    );
  }
}

class _Cells extends StatelessWidget {
  const _Cells(this.value, this.onSet);
  final int value;
  final ValueChanged<int> onSet;

  @override
  Widget build(BuildContext context) => Row(children: [
        for (var k = 0; k < 10; k++)
          Padding(
            padding: EdgeInsets.only(left: k == 0 ? 0 : 3),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSet(k + 1),
              child: SizedBox(
                width: 13,
                height: 44,
                child: Center(
                  child: SizedBox(
                      width: 13,
                      height: 16,
                      child: ColoredBox(color: k < value ? C.ink : C.line)),
                ),
              ),
            ),
          ),
      ]);
}

class _Toggle extends StatelessWidget {
  const _Toggle(this.on, this.onTap);
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(on ? '[ ON ]' : '[ OFF ]',
                style: mono(12, tracking: .16, color: on ? C.ink : C.muted)),
          ),
        ),
      );
}
