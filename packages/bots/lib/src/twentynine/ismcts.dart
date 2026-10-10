import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';

import 'cards.dart';
import 'knowledge.dart';
import 'sim.dart';

/// The move of asking for trump. Card plays are card indices, 0 to 31.
const int askMove = 32;

/// One node of the search tree: a move, and how it has done.
final class _Node {
  _Node(this.move, this.seat);

  /// The move that leads here, or -1 at the root.
  final int move;

  /// The seat that made [move].
  final int seat;

  final List<_Node> children = [];
  int visits = 0;
  int available = 0;
  double reward = 0;

  _Node? child(int move) {
    for (final child in children) {
      if (child.move == move) return child;
    }
    return null;
  }
}

/// Information Set Monte Carlo Tree Search (AGENTS.md §8.3.5).
///
/// One tree over what the bot knows. Each iteration takes the next of
/// [worlds], walks the tree choosing moves legal in that world by UCB1
/// with availability counts, adds one new move, plays the rest of the deal
/// out with the [Greedy] policy and credits every move on the way with how
/// its side did. Unlike solving each world on its own, no player in the
/// tree acts on cards it could not see.
final class Ismcts {
  /// A search of [view] over [worlds], drawing on [random].
  Ismcts(this.view, this.k, this.worlds, this.random);

  /// The bot's view.
  final TwentyNineView view;

  /// What the view shows for certain.
  final Knowledge k;

  /// The deals to search, used in turn.
  final List<World> worlds;

  /// The bot's own random numbers.
  final Xoshiro256StarStar random;

  /// The exploration weight of UCB1, for rewards between 0 and 1.
  static const double exploration = 0.7;

  /// The move the bot should make after [iterations] iterations: the one
  /// tried most often at the root.
  int search(int iterations) {
    final me = view.seat.index;
    final root = _Node(-1, -1);
    final ownSeat = me;
    for (var i = 0; i < iterations; i++) {
      final world = worlds[i % worlds.length];
      final sim = simulate(view, k, world);
      final target = view.target ?? view.config.maxBid;
      var node = root;
      final path = <_Node>[];
      while (!sim.over) {
        final seat = sim.turn;
        final moves = _moves(sim, seat);
        if (moves.isEmpty) break;
        final untried = [
          for (final move in moves)
            if (node.child(move) == null) move,
        ];
        _Node next;
        if (untried.isNotEmpty) {
          final move = untried[random.nextBounded(untried.length)];
          next = _Node(move, seat);
          node.children.add(next);
          for (final move in moves) {
            node.child(move)?.available++;
          }
          _apply(sim, seat, move);
          path.add(next);
          break;
        }
        var best = node.children.first;
        var bestScore = double.negativeInfinity;
        for (final move in moves) {
          final child = node.child(move)!;
          child.available++;
          final score =
              child.reward / child.visits +
              exploration * math.sqrt(math.log(child.available) / child.visits);
          if (score > bestScore) {
            bestScore = score;
            best = child;
          }
        }
        _apply(sim, seat, best.move);
        path.add(best);
        node = best;
      }
      sim.playOut();
      final rewards = _rewards(sim, target);
      for (final visited in path) {
        visited.visits++;
        visited.reward += rewards[visited.seat & 1];
      }
    }
    var choice = root.children.first;
    for (final child in root.children) {
      if (child.seat == ownSeat && child.visits > choice.visits) choice = child;
    }
    return choice.move;
  }

  /// The moves of [seat]: its legal cards, and asking for trump when it
  /// may. Under the mandatory rule, asking is its only move then.
  static List<int> _moves(Sim sim, int seat) {
    final cards = C29.list(sim.legal(seat));
    if (!sim.canAsk(seat)) return cards;
    return sim.mustAsk ? [askMove] : [...cards, askMove];
  }

  static void _apply(Sim sim, int seat, int move) {
    if (move == askMove) {
      sim.ask(seat);
    } else {
      sim.play(seat, move);
    }
  }

  /// Each team's reward for the finished deal in [sim]: 1 for meeting its
  /// goal, 0 for failing, a half each for a void deal, plus a little for
  /// card points to break ties (AGENTS.md §8.3.7).
  static List<double> _rewards(Sim sim, int target) {
    final side = Sim.team(sim.declarer >= 0 ? sim.declarer : sim.bidder);
    final double sideReward;
    if (sim.declarer >= 0) {
      sideReward = sim.tricksWon[1 - side] == 0 ? 1 : 0;
    } else if (!sim.revealed) {
      sideReward = 0.5;
    } else {
      sideReward = sim.points[side] >= target ? 1 : 0;
    }
    final lead = (sim.points[side] - sim.points[1 - side]) / 29 * 0.02;
    final rewards = [0.0, 0.0];
    rewards[side] = sideReward + lead;
    rewards[1 - side] = 1 - sideReward - lead;
    return rewards;
  }
}

/// The action for [move], made by the seat of [view].
TwentyNineAction actionOf(TwentyNineView view, int move) =>
    move == askMove ? AskTrump(view.seat) : PlayCard(view.seat, C29.card(move));
