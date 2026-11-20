import '../core/game_rules.dart';
import '../core/level_plan.dart';
import '../core/missions.dart';
import '../core/stats.dart';
import 'memory_engine.dart';

class MemoryRules extends GameRules<MemoryLevel> {
  @override
  String get gameId => 'game-067-memory-cards-kids';

  @override
  List<String> get optionalMechanics => const ['peek'];

  @override
  List<GameModeId> get modes => const [GameModeId.campaign, GameModeId.endless, GameModeId.timeAttack, GameModeId.daily, GameModeId.weekly, GameModeId.challenge, GameModeId.zen];

  @override
  List<GameStat> get gameStats => const [
        GameStat('pairs_found', 'Bulunan eş', 'Pairs found', scale: 100),
        GameStat('boards_cleared', 'Biten oyun', 'Boards cleared', scale: 10),
        GameStat('perfect_boards', 'Hatasız oyun', 'Perfect boards', scale: 3),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('m1', 'pairs_found', [10, 25, 50]),
        MissionTemplate('m2', 'boards_cleared', [1, 3, 5], coinReward: 80),
      ];

  @override
  MemoryLevel generate(LevelSpec spec) => generateMemory(spec);

  @override
  Validation validate(MemoryLevel l, LevelSpec spec) {
    final e = checkMemory(l);
    return e == null ? Validation.ok(l.pairs) : Validation.fail(e);
  }
}

GameRules createRules() => MemoryRules();
