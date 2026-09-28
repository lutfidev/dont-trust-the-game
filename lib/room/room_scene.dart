import 'dart:ui';

import '../theme.dart';

class Tile {
  const Tile(this.i, this.j);
  final int i;
  final int j;

  @override
  bool operator ==(Object other) =>
      other is Tile && other.i == i && other.j == j;

  @override
  int get hashCode => i * 10 + j;

  @override
  String toString() => 'Tile($i, $j)';
}

class TileHighlight {
  const TileHighlight(this.tile, this.color);
  final Tile tile;
  final Color color;
}

/// Text scratched onto a wall. [wall] is 'r' (right/back wall along i) or
/// 'l' (left wall along j); [at] is the tile coordinate along that wall.
class WallText {
  const WallText(this.text,
      {required this.wall,
      required this.at,
      required this.z,
      this.size = 8,
      this.opacity = .3,
      this.color = C.ink});
  final String text;
  final String wall;
  final double at;
  final double z;
  final double size;
  final double opacity;
  final Color color;
}

/// Everything the Flame room renders. Components read these fields every
/// frame, so the game controller can mutate the scene directly.
class RoomScene {
  RoomScene({
    this.player,
    this.doorOpen = false,
    this.drawerOpen = false,
    this.keyOnFloor = false,
    this.highlights = const [],
    this.doorHint = false,
    this.doorColor = C.safe,
    this.glitch = 0,
    this.crack = false,
    this.secret = false,
    this.noWalls = false,
    this.noDoor = false,
    this.noCabinet = false,
    this.noLamp = false,
    this.wallText = const [],
  });

  Tile? player;
  bool doorOpen;
  bool drawerOpen;
  bool keyOnFloor;
  List<TileHighlight> highlights;
  bool doorHint;
  Color doorColor;

  /// 0 = stable, 1 = light slices (live stages 03–04), 2 = heavy (glitch sheet).
  int glitch;
  bool crack;
  bool secret;
  bool noWalls;
  bool noDoor;
  bool noCabinet;
  bool noLamp;
  List<WallText> wallText;

  void Function(Tile tile)? onTile;
  VoidCallback? onDoor;
  VoidCallback? onCabinet;
  VoidCallback? onCrack;
}

/// The history of instructions written on the walls of the secret room.
/// Left-wall lines are wrapped short so they stop before the bright opening.
const truthWallText = [
  WallText('MOVE RIGHT.', wall: 'r', at: .5, z: 96, opacity: .32),
  WallText('OPEN THE DOOR.', wall: 'r', at: .5, z: 86, opacity: .26),
  WallText('THE KEY IS IN', wall: 'r', at: .5, z: 76, opacity: .2),
  WallText('THE DRAWER.', wall: 'r', at: .5, z: 68, opacity: .2),
  WallText('TRUST ME.', wall: 'r', at: .5, z: 56, opacity: .34),
  WallText('GO THROUGH.', wall: 'r', at: .5, z: 46, opacity: .16),
  WallText("DON'T GO", wall: 'l', at: 5.8, z: 96, opacity: .26),
  WallText('THERE.', wall: 'l', at: 5.8, z: 88, opacity: .26),
  WallText('I LIED.', wall: 'l', at: 5.8, z: 76, opacity: .5, color: C.warn),
  WallText('YOU ALWAYS', wall: 'l', at: 5.8, z: 64, opacity: .2),
  WallText('GO LEFT.', wall: 'l', at: 5.8, z: 56, opacity: .2),
  WallText('WHY ARE YOU', wall: 'l', at: 5.8, z: 44, opacity: .18),
  WallText('NOT MOVING?', wall: 'l', at: 5.8, z: 36, opacity: .18),
];

/// The real drawer code, faintly scratched on the right wall in stage 02.
/// Kept compact and left of the door so no digit is hidden behind the frame.
const codeWallText =
    WallText('4·0·7·1', wall: 'r', at: .95, z: 58, size: 11, opacity: .3);
