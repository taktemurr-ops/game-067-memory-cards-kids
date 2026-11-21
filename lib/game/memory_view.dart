import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/play_kit.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';
import 'kids_ui.dart';
import 'memory_engine.dart';
import 'rules.dart';

/// Grid of memory cards (also used by Mini Games).
class MemoryBoard extends StatelessWidget {
  final MemoryGame game;
  final bool showAll;
  final Set<int> flash;
  final void Function(int) onTap;
  const MemoryBoard({super.key, required this.game, required this.onTap, this.showAll = false, this.flash = const {}});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = game.level;
    final rows = (l.cards.length / l.cols).ceil();
    return LayoutBuilder(
      builder: (context, c) {
        final size = math.max(
          40.0,
          math.min(150.0, math.min((c.maxWidth - 16) / l.cols - 10, (c.maxHeight - 16) / rows - 10)),
        );
        return Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < l.cards.length; i++)
                SizedBox(
                  width: size,
                  height: size,
                  child: Semantics(
                    button: true,
                    label: game.isFaceUp(i) || showAll ? l.faces[l.cards[i]] : '?',
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (w, a) => ScaleTransition(scale: a, child: w),
                        child: (game.isFaceUp(i) || showAll || flash.contains(i))
                            ? Container(
                                key: ValueKey('f$i'),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: game.matched[i] ? Colors.green.shade100 : Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: game.matched[i] ? Colors.green : cs.primary, width: 3),
                                ),
                                child: FittedBox(
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Text(l.faces[l.cards[i]], style: const TextStyle(fontSize: 60)),
                                  ),
                                ),
                              )
                            : Container(
                                key: ValueKey('b$i'),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [cs.primary, cs.tertiary]),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: const [
                                    BoxShadow(blurRadius: 3, offset: Offset(0, 2), color: Colors.black26),
                                  ],
                                ),
                                child: Icon(Icons.star_rounded, color: Colors.white70, size: size * .45),
                              ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class MemoryView extends StatefulWidget {
  final PlayContext ctx;
  const MemoryView({super.key, required this.ctx});

  @override
  State<MemoryView> createState() => _MemoryViewState();
}

class _MemoryViewState extends State<MemoryView> with RoundClock {
  late MemoryLevel level;
  late MemoryGame game;
  late SeededRandom _r;
  int _hints = 0;
  int _rounds = 0;
  int _pairsTotal = 0;
  int _boards = 0;
  bool _peeking = false;
  Timer? _peekTimer;
  bool _busy = false;
  bool _ended = false;
  Set<int> _flash = {};
  String _msg = '';
  bool _ok = true;

  PlayContext get ctx => widget.ctx;
  bool get _tr => isTr(ctx);
  bool get _chain => const [GameModeId.endless, GameModeId.timeAttack].contains(ctx.spec.mode);

  @override
  void initState() {
    super.initState();
    level = (ctx.generated as GeneratedLevel<MemoryLevel>).puzzle;
    final snap = ctx.resume['snap'];
    game = snap is String ? MemoryGame.restore(level, snap) : MemoryGame(level);
    _hints = (ctx.resume['hints'] as num?)?.toInt() ?? 0;
    _rounds = (ctx.resume['solved'] as num?)?.toInt() ?? 0;
    _r = SeededRandom(mixSeed([ctx.spec.seed, 61]));
    startClock(
      initialSeconds: (ctx.resume['secs'] as num?)?.toInt() ?? 0,
      limit: ctx.spec.mode == GameModeId.timeAttack ? 120 : 0,
    );
    if (snap is! String) _peek();
  }

  /// Shows every card for a moment (easy levels / 'peek' mechanic).
  void _peek() {
    if (level.peek <= 0) return;
    _peeking = true;
    final my = level;
    _peekTimer?.cancel();
    _peekTimer = Timer(Duration(seconds: level.peek), () {
      if (mounted && identical(my, level)) setState(() => _peeking = false);
    });
  }

  @override
  void dispose() {
    _peekTimer?.cancel();
    stopClock();
    super.dispose();
  }

  @override
  void onTimeUp() => _end();

  void _persist() => ctx.saveResume({'snap': game.serialize(), 'secs': seconds, 'hints': _hints, 'solved': _rounds});

  Future<void> _tap(int i) async {
    if (_busy || _peeking || _ended) return;
    final res = game.flip(i);
    if (res < 0) return;
    ctx.sfx(Sfx.tap);
    setState(() {});
    if (res == 1) {
      _pairsTotal++;
      ctx.sfx(Sfx.coin);
      setState(() {
        _msg = cheer(ctx, _pairsTotal);
        _ok = true;
      });
      _persist();
      if (game.done) _boardDone();
    } else if (res == 2) {
      _busy = true;
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() {
        game.closeOpen();
        _msg = tryAgain(ctx, game.misses);
        _ok = false;
      });
      _busy = false;
      _persist();
    }
  }

  Future<void> _boardDone() async {
    _boards++;
    ctx.sfx(Sfx.win);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    if (_chain) {
      _rounds++;
      final next = ctx.spec.copyWith(seed: mixSeed([ctx.spec.seed, _rounds]));
      setState(() {
        level = createRules().build(next).puzzle as MemoryLevel;
        game = MemoryGame(level);
        _msg = '';
        _peek();
      });
      _persist();
      return;
    }
    _end();
  }

  void _end() {
    if (_ended) return;
    _ended = true;
    stopClock();
    var stars = game.stars();
    if (_chain) stars = _rounds >= 3 ? 3 : (_rounds >= 1 ? 2 : 1);
    ctx.finish(
      RoundResult(
        won: game.done || _boards > 0 || (_chain && _pairsTotal > 0),
        score: _pairsTotal * 100 + _boards * 300 + game.bestStreak * 50,
        stars: stars,
        seconds: seconds,
        moves: game.moves,
        hintsUsed: _hints,
        gameStats: {
          'pairs_found': _pairsTotal,
          'boards_cleared': _boards,
          'perfect_boards': game.done && game.misses == 0 ? 1 : 0,
        },
      ),
    );
  }

  Future<void> _hint() async {
    if (_busy || _peeking || game.done || !await ctx.requestHint()) return;
    final p = game.somePair(_r);
    if (p == null) return;
    _hints++;
    setState(() => _flash = {p.$1, p.$2});
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (mounted) setState(() => _flash = {});
  }

  Future<void> _match() async {
    if (_busy || _peeking || game.done || !await ctx.requestBooster()) return;
    final p = game.somePair(_r);
    if (p == null) return;
    setState(() => game.forceMatch(p.$1, p.$2));
    _pairsTotal++;
    ctx.sfx(Sfx.coin);
    _persist();
    if (game.done) _boardDone();
  }

  @override
  Widget build(BuildContext context) {
    final th = kMemoryThemes[level.theme % kMemoryThemes.length];
    return KidsBackdrop(
      colors: ctx.background,
      child: Column(
        children: [
          PlayHud(
            items: [
              if (ctx.spec.mode == GameModeId.timeAttack) (Icons.timer, timeText),
              (Icons.style, '${game.pairsFound}/${level.pairs}'),
              (Icons.touch_app, '${game.moves}'),
              if (_chain) (Icons.emoji_events, '$_rounds'),
            ],
          ),
          Text(
            _peeking ? (_tr ? 'İyi bak! 👀' : 'Look closely! 👀') : (_tr ? th.$2 : th.$1),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: MemoryBoard(game: game, onTap: _tap, showAll: _peeking, flash: _flash),
            ),
          ),
          CheerLine(_msg, good: _ok),
          BoosterBar(
            buttons: [
              BoosterButton(Icons.lightbulb, ctx.t('hint'), _hint),
              BoosterButton(Icons.auto_awesome, _tr ? 'Eşleştir' : 'Match one', _match),
            ],
          ),
        ],
      ),
    );
  }
}
