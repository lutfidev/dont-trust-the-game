import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../room/room_scene.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'boot.dart';
import 'settings_screen.dart';

/// 01 — Main menu. The title only says "TRUST THE GAME"; "don't" is a
/// hand-scrawled red note — the one clue from the very start.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  final _scene = RoomScene(player: const Tile(2, 3), doorHint: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DesignFrame(
        child: Stack(children: [
          Positioned(
            top: 250,
            left: 0,
            child: Opacity(opacity: .6, child: IgnorePointer(child: RoomView(_scene))),
          ),
          Positioned(
            top: 26,
            right: 22,
            child: Text('v1.0', style: mono(10, color: C.muted, tracking: .2)),
          ),
          Positioned(
            top: 110,
            left: 28,
            right: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 4),
                  child: Transform.rotate(
                    angle: -3 * math.pi / 180,
                    alignment: Alignment.bottomLeft,
                    child: Text("don't", style: serif(30, color: C.warn, height: 1)),
                  ),
                ),
                Text('TRUST\nTHE GAME',
                    style: mono(44, weight: FontWeight.w600, tracking: -.01, height: .98)),
                const SizedBox(height: 18),
                Text('> EVERYTHING IS FINE.', style: mono(11, color: C.muted, tracking: .2)),
              ],
            ),
          ),
          Positioned(
            left: 28,
            right: 28,
            bottom: 38,
            child: Column(children: [
              BlockButton('[ START ]',
                  kind: BtnKind.primary,
                  arrow: true,
                  onTap: () => Navigator.of(context).push(fadeRoute(const BootScreen()))),
              const SizedBox(height: 10),
              BlockButton('[ SETTINGS ]',
                  onTap: () =>
                      Navigator.of(context).push(fadeRoute(const SettingsScreen()))),
              const SizedBox(height: 10),
              BlockButton('[ QUIT ]', kind: BtnKind.muted, onTap: SystemNavigator.pop),
            ]),
          ),
        ]),
      ),
    );
  }
}
