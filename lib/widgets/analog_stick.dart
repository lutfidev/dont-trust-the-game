import 'package:flutter/material.dart';

import '../theme.dart';

class AnalogStick extends StatefulWidget {
  const AnalogStick({super.key, required this.onChanged});

  final ValueChanged<Offset> onChanged;

  @override
  State<AnalogStick> createState() => _AnalogStickState();
}

class _AnalogStickState extends State<AnalogStick> {
  static const _size = 104.0;
  static const _travel = 30.0;
  Offset _offset = Offset.zero;

  void _update(Offset localPosition) {
    if (!mounted) return;
    var offset = localPosition - const Offset(_size / 2, _size / 2);
    final distance = offset.distance;
    if (distance > _travel) offset *= _travel / distance;
    setState(() => _offset = offset);
    widget.onChanged(Offset(offset.dx / _travel, offset.dy / _travel));
  }

  void _release() {
    if (mounted) setState(() => _offset = Offset.zero);
    widget.onChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: _size,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (event) => _update(event.localPosition),
      onPanUpdate: (event) => _update(event.localPosition),
      onPanEnd: (_) => _release(),
      onPanCancel: _release,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: C.panel.withValues(alpha: .88),
              shape: BoxShape.circle,
              border: Border.all(color: C.borderHi),
            ),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: C.line),
            ),
          ),
          Positioned(
            left: _size / 2 - 19 + _offset.dx,
            top: _size / 2 - 19 + _offset.dy,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: C.ink,
                shape: BoxShape.circle,
                border: Border.all(color: C.muted, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: C.warn,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
