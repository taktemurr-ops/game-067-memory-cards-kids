import 'package:flutter_test/flutter_test.dart';
import 'package:game_067_memory_cards_kids/core/level_plan.dart';
import 'package:game_067_memory_cards_kids/core/rng.dart';
import 'package:game_067_memory_cards_kids/game/memory_engine.dart';
import 'package:game_067_memory_cards_kids/game/rules.dart';

void main() {
  final rules = MemoryRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('boards are valid and grow with difficulty', () {
    for (final n in [1, 2, 10, 99, 1234, 20000, 49999, 52000]) {
      final l = rules.build(planner.spec(n)).puzzle;
      expect(checkMemory(l), isNull, reason: 'level $n');
      expect(l.pairs, memoryPairs(planner.spec(n).difficulty));
    }
  });

  test('a perfect memory clears the board with three stars', () {
    final l = rules.build(planner.spec(40)).puzzle;
    final g = MemoryGame(l);
    for (var p = 0; p < l.pairs; p++) {
      final idx = [for (var i = 0; i < l.cards.length; i++) if (l.cards[i] == p) i];
      expect(g.flip(idx[0]), 0);
      expect(g.flip(idx[1]), 1);
    }
    expect(g.done, isTrue);
    expect(g.misses, 0);
    expect(g.stars(), 3);
  });

  test('mismatch closes, matched cards stay; restore', () {
    final l = rules.build(planner.spec(41)).puzzle;
    final g = MemoryGame(l);
    final a = 0;
    final b = [for (var i = 1; i < l.cards.length; i++) if (l.cards[i] != l.cards[0]) i].first;
    g.flip(a);
    expect(g.flip(b), 2);
    expect(g.flip(3 == a ? 4 : 3), -1);
    g.closeOpen();
    expect(g.misses, 1);
    final p = g.somePair(SeededRandom(2))!;
    g.forceMatch(p.$1, p.$2);
    expect(g.pairsFound, 1);
    expect(MemoryGame.restore(l, g.serialize()).serialize(), g.serialize());
  });

  test('levels 1..80 valid', () {
    for (var n = 1; n <= 80; n++) {
      expect(rules.build(planner.spec(n)).validation.ok, isTrue, reason: 'level $n');
    }
  });
}
