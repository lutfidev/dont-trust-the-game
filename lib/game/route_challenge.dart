import '../room/room_scene.dart';

class RouteChallenge {
  const RouteChallenge({
    required this.stage,
    required this.name,
    required this.instruction,
    required this.map,
    required this.route,
    this.obstacles = const [],
    this.timeLimitSeconds = 0,
  });

  final int stage;
  final String name;
  final String instruction;
  final RoomMap map;
  final List<Tile> route;
  final List<Tile> obstacles;
  final int timeLimitSeconds;

  static const all = [
    RouteChallenge(
      stage: 6,
      name: '06 / THE ARCHIVE',
      instruction: 'FOLLOW THE TWO MARKS.',
      map: RoomMap.archive,
      route: [Tile(2, 4), Tile(3, 4)],
    ),
    RouteChallenge(
      stage: 7,
      name: '07 / REDACTIONS',
      instruction: 'THREE MARKS. IN ORDER.',
      map: RoomMap.archive,
      route: [Tile(2, 4), Tile(2, 3), Tile(3, 3)],
      obstacles: [Tile(5, 5)],
    ),
    RouteChallenge(
      stage: 8,
      name: '08 / PALIMPSEST',
      instruction: 'THE LAST MARK IS NOT THE EXIT.',
      map: RoomMap.archive,
      route: [Tile(2, 4), Tile(3, 4), Tile(4, 4), Tile(4, 3)],
      obstacles: [Tile(2, 2), Tile(5, 0)],
    ),
    RouteChallenge(
      stage: 9,
      name: '09 / GLASS GARDEN',
      instruction: 'THE SAFE PATH BENDS.',
      map: RoomMap.greenhouse,
      route: [Tile(2, 4), Tile(3, 4), Tile(3, 3), Tile(4, 3)],
      obstacles: [Tile(1, 1), Tile(5, 0)],
    ),
    RouteChallenge(
      stage: 10,
      name: '10 / FALSE BLOOM',
      instruction: 'IGNORE THE MARK THAT REPEATS.',
      map: RoomMap.greenhouse,
      route: [Tile(2, 4), Tile(2, 3), Tile(3, 3), Tile(3, 2), Tile(4, 2)],
      obstacles: [Tile(5, 0), Tile(1, 1)],
    ),
    RouteChallenge(
      stage: 11,
      name: '11 / THORNS',
      instruction: 'FIVE MARKS. NO SHORTCUTS.',
      map: RoomMap.greenhouse,
      route: [Tile(2, 4), Tile(3, 4), Tile(4, 4), Tile(4, 3), Tile(4, 2)],
      obstacles: [Tile(2, 2), Tile(5, 0)],
    ),
    RouteChallenge(
      stage: 12,
      name: '12 / THE TOWER',
      instruction: 'THE SIGNAL IS FADING. MOVE.',
      map: RoomMap.tower,
      route: [
        Tile(2, 4),
        Tile(3, 4),
        Tile(3, 3),
        Tile(2, 3),
        Tile(2, 2),
        Tile(3, 2),
      ],
      obstacles: [Tile(1, 1), Tile(5, 5)],
      timeLimitSeconds: 24,
    ),
    RouteChallenge(
      stage: 13,
      name: '13 / DEAD AIR',
      instruction: 'SIX MARKS. THE CLOCK IS REAL.',
      map: RoomMap.tower,
      route: [
        Tile(2, 4),
        Tile(3, 4),
        Tile(3, 3),
        Tile(4, 3),
        Tile(4, 2),
        Tile(5, 2),
      ],
      obstacles: [Tile(1, 1), Tile(2, 2)],
      timeLimitSeconds: 22,
    ),
    RouteChallenge(
      stage: 14,
      name: '14 / BLACKOUT',
      instruction: 'SIX MARKS. ONE WRONG TURN COSTS TIME.',
      map: RoomMap.tower,
      route: [
        Tile(2, 4),
        Tile(2, 3),
        Tile(3, 3),
        Tile(4, 3),
        Tile(4, 2),
        Tile(5, 2),
      ],
      obstacles: [Tile(1, 1), Tile(5, 5), Tile(2, 2)],
      timeLimitSeconds: 19,
    ),
    RouteChallenge(
      stage: 15,
      name: '15 / THE CORE',
      instruction: 'NO ONE CAN WALK THIS FOR YOU.',
      map: RoomMap.core,
      route: [
        Tile(2, 4),
        Tile(3, 4),
        Tile(3, 3),
        Tile(4, 3),
        Tile(4, 2),
        Tile(5, 2),
        Tile(5, 1),
      ],
      obstacles: [Tile(1, 1), Tile(2, 2), Tile(5, 5)],
      timeLimitSeconds: 22,
    ),
  ];

  static RouteChallenge at(int stage) => all[stage - 6];
}
