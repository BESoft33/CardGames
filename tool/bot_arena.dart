import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:bots/bots.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';

const String _usage = '''
Plays duplicate deals of Twenty-Nine between two bot levels (AGENTS.md §8.4).

Each deal is played twice with the same cards and dealer: once with bot A at
seats 0 and 2, once with A at seats 1 and 3. A deal's score is A's net game
points over both plays, so the luck of the cards cancels out.

Usage: dart run tool/bot_arena.dart --a <level> --b <level> [options]

  --a <level>       beginner, casual, skilled, expert or master
  --b <level>       beginner, casual, skilled, expert or master
  --deals <n>       duplicate deals to play (default 2000)
  --seed <n>        seed for deals and bots (default 1)
  --workers <n>     worker isolates (default: number of processors)
  --markdown        also print a table row for docs/bot-benchmarks.md
''';

Future<void> main(List<String> arguments) async {
  final options = _parse(arguments);
  if (options == null) {
    stderr.write(_usage);
    exitCode = 64;
    return;
  }
  final watch = Stopwatch()..start();
  final chunks = _split(options.deals, options.workers);
  final parts = await Future.wait([
    for (final (start, end) in chunks)
      Isolate.run(() => _play(options.a, options.b, options.seed, start, end)),
  ]);
  final results = [for (final part in parts) ...part];
  watch.stop();
  _report(options, results, watch.elapsed);
}

final class _Options {
  _Options(this.a, this.b, this.deals, this.seed, this.workers, this.markdown);

  final BotLevel a;
  final BotLevel b;
  final int deals;
  final int seed;
  final int workers;
  final bool markdown;
}

_Options? _parse(List<String> arguments) {
  BotLevel? a;
  BotLevel? b;
  var deals = 2000;
  var seed = 1;
  var workers = Platform.numberOfProcessors;
  var markdown = false;
  BotLevel? level(String name) =>
      BotLevel.values.where((l) => l.name == name).firstOrNull;
  for (var i = 0; i < arguments.length; i++) {
    final argument = arguments[i];
    String? value() => i + 1 < arguments.length ? arguments[++i] : null;
    switch (argument) {
      case '--a':
        a = level(value() ?? '');
      case '--b':
        b = level(value() ?? '');
      case '--deals':
        deals = int.tryParse(value() ?? '') ?? -1;
      case '--seed':
        seed = int.tryParse(value() ?? '') ?? 0;
      case '--workers':
        workers = int.tryParse(value() ?? '') ?? -1;
      case '--markdown':
        markdown = true;
      default:
        return null;
    }
  }
  if (a == null || b == null || deals < 1 || workers < 1) return null;
  return _Options(a, b, deals, seed, workers, markdown);
}

List<(int, int)> _split(int deals, int workers) {
  final size = (deals / workers).ceil();
  return [
    for (var start = 0; start < deals; start += size)
      (start, math.min(deals, start + size)),
  ];
}

/// One play of one deal, from bot A's side.
final class _Play {
  const _Play(this.net, this.aBid, this.outcome, this.contract, this.stake);

  /// A's game points minus B's from this deal.
  final int net;

  /// Whether A's team won the auction.
  final bool aBid;

  /// How the deal ended.
  final DealOutcome outcome;

  /// The contract, or 0 for single hand.
  final int contract;

  /// The stake.
  final int stake;
}

const TwentyNineGame _game = TwentyNineGame();

/// Plays duplicate deals [start] to [end] - 1 and returns both plays of
/// each.
List<(_Play, _Play)> _play(
  BotLevel a,
  BotLevel b,
  int seed,
  int start,
  int end,
) {
  const runner = DirectBotRunner();
  final dealSeeds = SplitMix64(seed);
  final botSeeds = SplitMix64(seed ^ 0x2545F4914F6CDD1D);
  var dealSeed = 0;
  var botSeed = 0;
  for (var i = 0; i <= start; i++) {
    dealSeed = dealSeeds.next();
    botSeed = botSeeds.next();
  }
  final results = <(_Play, _Play)>[];
  for (var deal = start; deal < end; deal++) {
    if (deal > start) {
      dealSeed = dealSeeds.next();
      botSeed = botSeeds.next();
    }
    results.add((
      _playDeal(runner, a, b, aTeam: 0, dealSeed, botSeed),
      _playDeal(runner, a, b, aTeam: 1, dealSeed, botSeed ^ 1),
    ));
  }
  return results;
}

/// Plays the first deal of a match from [dealSeed], with A's team [aTeam].
_Play _playDeal(
  DirectBotRunner runner,
  BotLevel a,
  BotLevel b,
  int dealSeed,
  int botSeed, {
  required int aTeam,
}) {
  final bots = Xoshiro256StarStar.seeded(botSeed);
  var state = _game.init(const TwentyNineConfig().toMatchConfig(), dealSeed);
  for (;;) {
    final seat = state.turn!;
    final level = TwentyNineRules.teamOf(seat) == aTeam ? a : b;
    final view = _game.viewFor(state, seat);
    state = _game.apply(state, runner.decide(view, level, bots.nextInt64()));
    for (final event in state.lastEvents) {
      if (event is DealScored) {
        final forA = event.team == aTeam ? event.delta : -event.delta;
        return _Play(
          forA,
          event.team == aTeam,
          event.outcome,
          event.target ?? 0,
          event.stake,
        );
      }
    }
  }
}

void _report(_Options options, List<(_Play, _Play)> results, Duration time) {
  final scores = [for (final (x, y) in results) x.net + y.net];
  final n = scores.length;
  final mean = scores.fold(0, (s, v) => s + v) / n;
  final variance =
      scores.fold(0.0, (s, v) => s + (v - mean) * (v - mean)) / (n - 1);
  final error = math.sqrt(variance / n);
  final z = error == 0 ? 0.0 : mean / error;
  final p = _erfc(z.abs() / math.sqrt2);
  final ahead = scores.where((s) => s > 0).length;
  final behind = scores.where((s) => s < 0).length;
  final plays = [
    for (final (x, y) in results) ...[x, y],
  ];

  String side(bool forA) {
    final bids = plays.where((p) => p.aBid == forA && p.contract > 0);
    final made = bids.where((p) => p.outcome == DealOutcome.contractMade);
    final average = bids.isEmpty
        ? 0.0
        : bids.fold(0, (s, p) => s + p.contract) / bids.length;
    return '${bids.length} bids, ${_percent(made.length, bids.length)} made, '
        'average ${average.toStringAsFixed(1)}';
  }

  /// Doubles by one side: the other side bid, and the stake is 2 or 4.
  String doubles(bool byA) {
    final doubled = plays.where(
      (p) => p.aBid != byA && p.contract > 0 && p.stake >= 2,
    );
    final made = doubled.where((p) => p.outcome == DealOutcome.contractMade);
    final redoubled = doubled.where((p) => p.stake == 4).length;
    return '${doubled.length} (contract made in '
        '${_percent(made.length, doubled.length)}; redoubled $redoubled)';
  }

  final a = options.a.name;
  final b = options.b.name;
  stdout
    ..writeln('$a (A) against $b (B): $n duplicate deals, seed ${options.seed}')
    ..writeln(
      'A net game points per deal: ${mean.toStringAsFixed(3)} '
      '(95% interval ${(mean - 1.96 * error).toStringAsFixed(3)} to '
      '${(mean + 1.96 * error).toStringAsFixed(3)})',
    )
    ..writeln('z = ${z.toStringAsFixed(2)}, two-sided p = ${_pValue(p)}')
    ..writeln(
      'A ahead in $ahead deals, behind in $behind, level in '
      '${n - ahead - behind}',
    )
    ..writeln('A as bidder: ${side(true)}')
    ..writeln('B as bidder: ${side(false)}')
    ..writeln('A doubled ${doubles(true)}')
    ..writeln('B doubled ${doubles(false)}')
    ..writeln(
      'Voided deals: ${plays.where((p) => p.outcome == DealOutcome.voided).length}',
    )
    ..writeln('Time: ${time.inSeconds} s on ${options.workers} workers')
    ..writeln(
      p < 0.01 && mean > 0
          ? 'Verdict: A is stronger (p < 0.01).'
          : 'Verdict: no significant edge for A.',
    );
  if (options.markdown) {
    stdout.writeln(
      '| $a | $b | $n | ${mean.toStringAsFixed(3)} | '
      '${(mean - 1.96 * error).toStringAsFixed(3)} to '
      '${(mean + 1.96 * error).toStringAsFixed(3)} | '
      '${z.toStringAsFixed(2)} | ${_pValue(p)} | ${options.seed} |',
    );
  }
}

String _percent(int part, int whole) =>
    whole == 0 ? '-' : '${(100 * part / whole).toStringAsFixed(1)}%';

String _pValue(double p) => p < 1e-6 ? '< 0.000001' : p.toStringAsFixed(6);

/// The complementary error function (Abramowitz and Stegun 7.1.26), good to
/// about 1e-7: enough for a p-value.
double _erfc(double x) {
  final t = 1 / (1 + 0.3275911 * x);
  final poly =
      t *
      (0.254829592 +
          t *
              (-0.284496736 +
                  t * (1.421413741 + t * (-1.453152027 + t * 1.061405429))));
  return poly * math.exp(-x * x);
}
