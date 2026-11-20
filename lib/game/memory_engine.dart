import '../core/level_plan.dart';
import '../core/rng.dart';
import 'kids_data.dart';

/// Card sets (themes) for the memory games.
List<String> memorySet(int theme) {
  switch (theme % 5) {
    case 0:
      return [for (final a in kAnimals.take(30)) a.$1];
    case 1:
      return [
        for (final t in kThings)
          if (t.$4 == 'fruit' || t.$4 == 'veg') t.$1,
      ];
    case 2:
      return [
        for (final t in kThings)
          if (t.$4 == 'vehicle' || t.$4 == 'toy') t.$1,
      ];
    case 3:
      return [
        for (final t in kThings)
          if (t.$4 == 'nature' || t.$4 == 'clothes') t.$1,
      ];
    default:
      return [for (final a in kAnimals.skip(16)) a.$1];
  }
}

const kMemoryThemes = [
  ('Animals', 'Hayvanlar'),
  ('Fruits & veggies', 'Meyve ve sebze'),
  ('Toys & vehicles', 'Oyuncak ve taşıt'),
  ('Nature & clothes', 'Doğa ve giysi'),
  ('Wild friends', 'Vahşi dostlar'),
];

class MemoryLevel {
  final int theme;

  /// Emoji per pair.
  final List<String> faces;

  /// Card -> pair index; every pair appears exactly twice.
  final List<int> cards;
  final int cols;

  /// Seconds all cards are shown at the start (0 = none).
  final int peek;
  const MemoryLevel(this.theme, this.faces, this.cards, this.cols, this.peek);
  int get pairs => faces.length;
}

int memoryPairs(int d) => (2 + d).clamp(2, 10);

MemoryLevel generateMemory(LevelSpec spec, {int? pairs}) {
  final r = SeededRandom(spec.seed);
  final d = spec.difficulty;
  final n = pairs ?? memoryPairs(d);
  final set = memorySet(spec.theme + r.nextInt(5));
  final pool = [...set];
  r.shuffle(pool);
  final faces = pool.take(n).toList();
  final cards = [
    for (var i = 0; i < n; i++) ...[i, i],
  ];
  r.shuffle(cards);
  // Never leave a pair side by side at the very start.
  for (var i = 0; i + 1 < cards.length; i++) {
    if (cards[i] == cards[i + 1]) {
      final j = (i + 2 + r.nextInt(cards.length - 1)) % cards.length;
      final t = cards[i + 1];
      cards[i + 1] = cards[j];
      cards[j] = t;
    }
  }
  final total = n * 2;
  final cols = total <= 4 ? 2 : (total <= 6 ? 3 : (total <= 12 ? 4 : 5));
  final peek = spec.has('peek') || d <= 3 ? (d <= 3 ? 3 : 2) : 0;
  return MemoryLevel(spec.theme % 5, faces, cards, cols, peek);
}

String? checkMemory(MemoryLevel l) {
  if (l.pairs < 2) return 'too few pairs';
  if (l.faces.toSet().length != l.faces.length) return 'duplicate faces';
  if (l.cards.length != l.pairs * 2) return 'card count';
  for (var i = 0; i < l.pairs; i++) {
    if (l.cards.where((c) => c == i).length != 2) return 'pair $i not twice';
  }
  return null;
}

class MemoryGame {
  final MemoryLevel level;
  late final List<bool> matched;
  final List<int> open = [];
  int moves = 0;
  int misses = 0;
  int streak = 0;
  int bestStreak = 0;
  MemoryGame(this.level) {
    matched = List.filled(level.cards.length, false);
  }

  bool get done => matched.every((m) => m);
  int get pairsFound => matched.where((m) => m).length ~/ 2;

  bool isFaceUp(int i) => matched[i] || open.contains(i);

  /// Flips card [i]. Returns: -1 ignored, 0 first card, 1 match, 2 mismatch
  /// (call [closeOpen] after showing the mismatch).
  int flip(int i) {
    if (i < 0 || i >= matched.length || matched[i] || open.contains(i) || open.length >= 2) return -1;
    open.add(i);
    if (open.length == 1) return 0;
    moves++;
    final a = open[0], b = open[1];
    if (level.cards[a] == level.cards[b]) {
      matched[a] = matched[b] = true;
      open.clear();
      streak++;
      if (streak > bestStreak) bestStreak = streak;
      return 1;
    }
    misses++;
    streak = 0;
    return 2;
  }

  void closeOpen() => open.clear();

  /// Indices of one unmatched pair (for hints / boosters).
  (int, int)? somePair(SeededRandom r) {
    final left = [
      for (var i = 0; i < matched.length; i++)
        if (!matched[i]) i,
    ];
    if (left.isEmpty) return null;
    final a = r.pick(left);
    final b = left.firstWhere((j) => j != a && level.cards[j] == level.cards[a]);
    return (a, b);
  }

  void forceMatch(int a, int b) {
    matched[a] = matched[b] = true;
    open.clear();
  }

  int stars() {
    final p = level.pairs;
    if (misses <= (p / 2).ceil()) return 3;
    if (misses <= p * 2) return 2;
    return 1;
  }

  String serialize() => '$moves;$misses;$bestStreak;${[for (final m in matched) m ? 1 : 0].join()}';

  static MemoryGame restore(MemoryLevel l, String s) {
    final g = MemoryGame(l);
    final p = s.split(';');
    if (p.length == 4 && p[3].length == g.matched.length) {
      g.moves = int.tryParse(p[0]) ?? 0;
      g.misses = int.tryParse(p[1]) ?? 0;
      g.bestStreak = int.tryParse(p[2]) ?? 0;
      for (var i = 0; i < g.matched.length; i++) {
        g.matched[i] = p[3][i] == '1';
      }
    }
    return g;
  }
}
