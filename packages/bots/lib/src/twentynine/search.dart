import 'dart:typed_data';

import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';

import 'cards.dart';
import 'knowledge.dart';
import 'sim.dart';

/// The value of a finished deal for the side that bid (AGENTS.md §8.3.7):
/// the contract's outcome first, card points only to break ties.
///
/// A made contract is worth [made] plus the bidding side's points less 14,
/// a void deal just that tie-breaker, a failed one -[made] plus it. The
/// three bands never overlap. A single-hand deal is worth [made] or
/// -[made].
abstract final class DealValue {
  /// The weight of the outcome.
  static const int made = 100;

  /// The outcome of [value]: 1 made, 0 void, -1 failed.
  static int outcome(int value) => value > made ~/ 2
      ? 1
      : value < -made ~/ 2
      ? -1
      : 0;

  /// The tie-breaker in [value]: the bidding side's card points less 14,
  /// or 0 for single hand.
  static int points(int value) => value - outcome(value) * made;
}

/// The fixed facts of a deal under search.
final class DealRules {
  /// Creates the rules of one deal.
  const DealRules({
    required this.trump,
    required this.bidder,
    required this.target,
    this.declarer = -1,
    this.dutyToTrump = true,
    this.mustAsk = false,
    this.lastTrickPoint = true,
  });

  /// The rules of the deal [view] shows, with trump [trump] (-1 for none).
  factory DealRules.of(TwentyNineView view, int trump) {
    final config = view.config;
    final declarer = view.singleHandDeclarer?.index ?? -1;
    return DealRules(
      trump: declarer >= 0 ? -1 : trump,
      bidder: view.bidder?.index ?? view.firstPlayer.index,
      target: view.target ?? config.maxBid,
      declarer: declarer,
      dutyToTrump: config.askTrump == AskTrumpRule.optional,
      mustAsk: config.askTrump == AskTrumpRule.mandatory,
      lastTrickPoint: config.lastTrickPoint,
    );
  }

  /// The trump suit, or -1 when there is none.
  final int trump;

  /// The bidder's seat.
  final int bidder;

  /// The card points the bidding side needs.
  final int target;

  /// The single-hand declarer's seat, or -1.
  final int declarer;

  /// Whether a player who asks for trump must then trump if able.
  final bool dutyToTrump;

  /// Whether a player who cannot follow suit must ask for hidden trump.
  final bool mustAsk;

  /// Whether the last trick is worth a point.
  final bool lastTrickPoint;

  /// The team that maximises: the bidder's, or the declarer's.
  int get side => (declarer >= 0 ? declarer : bidder) & 1;

  /// Cards to a trick: three in single hand, four otherwise.
  int get trickSize => declarer >= 0 ? 3 : 4;

  /// The seat after [seat], skipping a single-hand declarer's partner.
  int seatAfter(int seat) {
    var next = (seat + 1) & 3;
    if (declarer >= 0 && next == ((declarer + 2) & 3)) next = (next + 1) & 3;
    return next;
  }
}

// The slots of a position. Hands are bit masks of card indices.
const int _hand0 = 0;
const int _seventh = 4;
const int _revealed = 5;
const int _leader = 6;
const int _length = 7;
const int _trick0 = 8;
const int _sidePoints = 12;
const int _otherPoints = 13;
const int _done = 14;
const int _lost = 15;
const int _mustTrump = 16;

/// Where in the current trick trump-suit cards start to count: see
/// [Sim.trumpFrom].
const int _trumpFrom = 17;

/// The number of slots in a position.
const int positionSlots = 18;

/// A move's flag: the player asks for trump, then plays the card.
const int askFlag = 32;

/// The most moves a player can have: eight cards, and eight more after
/// asking for trump.
const int _maxMoves = 16;

/// The deepest search: 32 cards and the root.
const int _maxPly = 34;

/// A position of a deal with every hand known (AGENTS.md §8.3.3), as
/// [positionSlots] integers.
final class DealPosition {
  DealPosition._(this.slots);

  /// The position [view] shows, with the cards the bot cannot see dealt
  /// as in [world].
  factory DealPosition.of(TwentyNineView view, World world) {
    final rules = DealRules.of(view, world.trump);
    final s = Int64List(positionSlots);
    for (var seat = 0; seat < 4; seat++) {
      s[_hand0 + seat] = world.hands[seat];
    }
    s[_seventh] = view.seventhCardSetAside ? world.seventh : -1;
    s[_revealed] = view.trumpRevealed ? 1 : 0;
    s[_leader] = view.trickLeader?.index ?? view.firstPlayer.index;
    s[_length] = view.trick.length;
    for (final (i, play) in view.trick.indexed) {
      s[_trick0 + i] = C29.index(play.card);
    }
    s[_sidePoints] = view.cardPoints[rules.side];
    s[_otherPoints] = view.cardPoints[1 - rules.side];
    s[_done] = view.tricks.length;
    var lost = 0;
    for (final trick in view.tricks) {
      if (TwentyNineRules.teamOf(trick.winner) != rules.side) lost++;
    }
    s[_lost] = lost;
    s[_mustTrump] = view.mustTrump?.index ?? -1;
    s[_trumpFrom] = trumpCountsFrom(view);
    return DealPosition._(s);
  }

  /// A position from raw slots, for tests.
  factory DealPosition.raw({
    required List<int> hands,
    required int leader,
    int seventh = -1,
    bool revealed = false,
    List<int> trick = const [],
    int sidePoints = 0,
    int otherPoints = 0,
    int done = 0,
  }) {
    final s = Int64List(positionSlots);
    for (var seat = 0; seat < 4; seat++) {
      s[_hand0 + seat] = hands[seat];
    }
    s[_seventh] = seventh;
    s[_revealed] = revealed ? 1 : 0;
    s[_leader] = leader;
    s[_length] = trick.length;
    for (final (i, card) in trick.indexed) {
      s[_trick0 + i] = card;
    }
    s[_sidePoints] = sidePoints;
    s[_otherPoints] = otherPoints;
    s[_done] = done;
    s[_mustTrump] = -1;
    s[_trumpFrom] = revealed && trick.isEmpty ? 0 : Sim.noTrump;
    return DealPosition._(s);
  }

  /// The slots.
  final Int64List slots;

  /// The cards still to be played: every hand and a hidden seventh card.
  int get cardsLeft {
    var left = 0;
    for (var seat = 0; seat < 4; seat++) {
      left += C29.count(slots[_hand0 + seat]);
    }
    return left + (slots[_seventh] >= 0 ? 1 : 0);
  }
}

/// Fixed random keys for hashing positions (Zobrist hashing, AGENTS.md
/// §8.3.3). They come from a constant seed, never from the deck or a bot.
final Int64List _zobrist = () {
  final random = Xoshiro256StarStar.seeded(0x29A11B0B);
  return Int64List.fromList([
    for (var i = 0; i < 32 * 5 + 64; i++) random.nextInt64(),
  ]);
}();

const int _zLeader = 32 * 5;
const int _zRevealed = _zLeader + 4;
const int _zPoints = _zRevealed + 1;
const int _zLost = _zPoints + 42;

// Transposition-table entries, packed into one integer.
const int _exact = 0;
const int _lower = 1;
const int _upper = 2;

/// Alpha-beta minimax over one deal with every hand known (AGENTS.md
/// §8.3.3): the bidding side maximises [DealValue], the other side
/// minimises it.
///
/// It keeps a transposition table at trick boundaries, orders moves
/// winners and point cards first, and treats cards that cannot play
/// differently as one. With more than [fullSearchCards] cards left it
/// looks to the end of the current trick only, then plays the rest out
/// with the [Greedy] policy. [nodeLimit] caps the work deterministically:
/// past it, every trick boundary is scored that way.
final class Solver {
  /// A solver for one deal under [rules].
  Solver(this.rules, {this.fullSearchCards = 16, this.nodeLimit = 300000});

  /// The deal's rules.
  final DealRules rules;

  /// The most cards left for a search to the end of the deal.
  final int fullSearchCards;

  /// The nodes after which the search stops looking past trick ends.
  final int nodeLimit;

  /// Nodes visited so far.
  int nodes = 0;

  final Int64List _s = Int64List(positionSlots * _maxPly);
  final Int32List _m = Int32List(_maxMoves * _maxPly);
  final Int32List _scores = Int32List(_maxMoves);
  final Map<int, int> _table = {};
  int _horizon = 8;

  /// The value of each move the player to act has in [position], as
  /// (move, value) pairs: a card index, plus [askFlag] for asking for trump
  /// first. Every legal card appears, equivalent ones included.
  List<(int, int)> solve(DealPosition position) {
    for (var i = 0; i < positionSlots; i++) {
      _s[i] = position.slots[i];
    }
    _horizon = position.cardsLeft <= fullSearchCards ? 8 : _s[_done] + 1;
    final count = _generate(0, 0, merge: false);
    final moves = [for (var i = 0; i < count; i++) _m[i]];
    final values = <(int, int)>[];
    for (final move in moves) {
      _apply(0, positionSlots, move);
      values.add((move, _search(1, -1000, 1000)));
    }
    return values;
  }

  /// The moves of the player to act in [position], every legal card
  /// included: a card index, plus [askFlag] for asking for trump first.
  List<int> moves(DealPosition position) {
    for (var i = 0; i < positionSlots; i++) {
      _s[i] = position.slots[i];
    }
    final count = _generate(0, 0, merge: false);
    return [for (var i = 0; i < count; i++) _m[i]];
  }

  /// The seat to play in the position at [b].
  int _turn(int b) {
    var seat = _s[b + _leader];
    final length = _s[b + _length];
    for (var i = 0; i < length; i++) {
      seat = rules.seatAfter(seat);
    }
    return seat;
  }

  int _value(int b) {
    if (rules.declarer >= 0) {
      return _s[b + _lost] == 0 ? DealValue.made : -DealValue.made;
    }
    final points = _s[b + _sidePoints];
    final tieBreak = points - 14;
    if (_s[b + _revealed] == 0) return tieBreak;
    return (points >= rules.target ? DealValue.made : -DealValue.made) +
        tieBreak;
  }

  int _search(int ply, int alpha, int beta) {
    final b = ply * positionSlots;
    nodes++;
    if (_s[b + _done] == 8) return _value(b);
    if (rules.declarer >= 0 && _s[b + _lost] > 0) return -DealValue.made;
    final boundary = _s[b + _length] == 0;
    if (boundary && (_s[b + _done] >= _horizon || nodes > nodeLimit)) {
      return _playOut(b);
    }
    var key = 0;
    var tableMove = -1;
    if (boundary) {
      key = _key(b);
      final entry = _table[key];
      if (entry != null) {
        final value = (entry >> 9) - 1000;
        final kind = entry & 3;
        tableMove = ((entry >> 2) & 127) - 1;
        if (kind == _exact) return value;
        if (kind == _lower && value > alpha) alpha = value;
        if (kind == _upper && value < beta) beta = value;
        if (alpha >= beta) return value;
      }
    }
    final seat = _turn(b);
    final maximise = (seat & 1) == rules.side;
    final out = ply * _maxMoves;
    final count = _generate(b, out, merge: true);
    _order(b, out, count, tableMove, seat);
    final alpha0 = alpha;
    final beta0 = beta;
    var best = maximise ? -100000 : 100000;
    var bestMove = _m[out];
    final next = b + positionSlots;
    for (var i = 0; i < count; i++) {
      final move = _m[out + i];
      _apply(b, next, move);
      final value = _search(ply + 1, alpha, beta);
      if (maximise) {
        if (value > best) {
          best = value;
          bestMove = move;
        }
        if (best > alpha) alpha = best;
      } else {
        if (value < best) {
          best = value;
          bestMove = move;
        }
        if (best < beta) beta = best;
      }
      if (alpha >= beta) break;
    }
    if (boundary) {
      final kind = best <= alpha0
          ? _upper
          : best >= beta0
          ? _lower
          : _exact;
      _table[key] = ((best + 1000) << 9) | ((bestMove + 1) << 2) | kind;
    }
    return best;
  }

  int _key(int b) {
    var key = 0;
    for (var seat = 0; seat < 4; seat++) {
      var mask = _s[b + _hand0 + seat];
      while (mask != 0) {
        final card = (mask & -mask).bitLength - 1;
        key ^= _zobrist[card * 5 + seat];
        mask &= mask - 1;
      }
    }
    final seventh = _s[b + _seventh];
    if (seventh >= 0) key ^= _zobrist[seventh * 5 + 4];
    key ^= _zobrist[_zLeader + _s[b + _leader]];
    if (_s[b + _revealed] != 0) key ^= _zobrist[_zRevealed];
    key ^= _zobrist[_zPoints + _s[b + _sidePoints]];
    key ^= _zobrist[_zLost + _s[b + _lost]];
    return key;
  }

  /// Writes the moves of the player to act at [b] from [out]; returns how
  /// many. With [merge], of cards that cannot play differently (next to
  /// each other in strength among the cards still out, and worth the same)
  /// only the strongest is kept.
  int _generate(int b, int out, {required bool merge}) {
    final seat = _turn(b);
    final hand = _s[b + _hand0 + seat];
    final seventh = _s[b + _seventh];
    if (hand == 0) {
      // Only the bidder's set-aside seventh card is left.
      if (seat == rules.bidder && seventh >= 0) {
        _m[out] = seventh;
        return 1;
      }
      return 0;
    }
    if (_s[b + _length] == 0) return _add(b, out, 0, hand, 0, merge);
    if (_s[b + _mustTrump] == seat) {
      final trumps = hand & C29.suitMask(rules.trump);
      return _add(b, out, 0, trumps != 0 ? trumps : hand, 0, merge);
    }
    final following = hand & C29.suitMask(C29.suitOf(_s[b + _trick0]));
    if (following != 0) return _add(b, out, 0, following, 0, merge);
    if (_s[b + _revealed] == 0 && rules.trump >= 0 && rules.declarer < 0) {
      final after = seat == rules.bidder && seventh >= 0
          ? hand | (1 << seventh)
          : hand;
      if (rules.mustAsk) return _add(b, out, 0, after, askFlag, merge);
      final plain = _add(b, out, 0, hand, 0, merge);
      final trumps = rules.dutyToTrump ? after & C29.suitMask(rules.trump) : 0;
      return _add(b, out, plain, trumps != 0 ? trumps : after, askFlag, merge);
    }
    return _add(b, out, 0, hand, 0, merge);
  }

  int _add(int b, int out, int from, int cards, int flag, bool merge) {
    var count = from;
    if (!merge) {
      var mask = cards;
      while (mask != 0) {
        final card = (mask & -mask).bitLength - 1;
        _m[out + count++] = card | flag;
        mask &= mask - 1;
      }
      return count;
    }
    var inPlay = 0;
    for (var seat = 0; seat < 4; seat++) {
      inPlay |= _s[b + _hand0 + seat];
    }
    final seventh = _s[b + _seventh];
    if (seventh >= 0) inPlay |= 1 << seventh;
    for (var suit = 0; suit < 4; suit++) {
      if (cards & C29.suitMask(suit) == 0) continue;
      var lastKept = false;
      var lastPoints = -1;
      for (final slot in C29.slotsByPower) {
        final card = suit * 8 + slot;
        if (inPlay & (1 << card) == 0) continue;
        if (cards & (1 << card) != 0) {
          final points = C29.points(card);
          if (!(lastKept && points == lastPoints)) {
            _m[out + count++] = card | flag;
          }
          lastKept = true;
          lastPoints = points;
        } else {
          lastKept = false;
        }
      }
    }
    return count;
  }

  /// Puts the most promising moves first: the table's best move, then cards
  /// that win the trick (richest first), then the cheapest of the rest.
  void _order(int b, int out, int count, int tableMove, int seat) {
    if (count < 2) return;
    final length = _s[b + _length];
    final ours = seat & 1;
    var winnerOurs = false;
    var bestStrength = -1;
    if (length > 0) {
      final led = C29.suitOf(_s[b + _trick0]);
      final revealed = _s[b + _revealed] != 0 && rules.trump >= 0;
      var player = _s[b + _leader];
      for (var i = 0; i < length; i++) {
        final card = _s[b + _trick0 + i];
        final strength = _strength(
          card,
          led,
          revealed && (i >= _s[b + _trumpFrom] || led == rules.trump),
        );
        if (strength > bestStrength) {
          bestStrength = strength;
          winnerOurs = (player & 1) == ours;
        }
        player = rules.seatAfter(player);
      }
    }
    for (var i = 0; i < count; i++) {
      final move = _m[out + i];
      final card = move & 31;
      var score = 0;
      if (move == tableMove) {
        score = 1 << 20;
      } else if (length == 0) {
        score = C29.power(card) * 8 + C29.points(card);
      } else {
        final led = C29.suitOf(_s[b + _trick0]);
        final trumpActive =
            (_s[b + _revealed] != 0 || move & askFlag != 0) &&
            rules.trump >= 0 &&
            rules.declarer < 0;
        final strength = _strength(card, led, trumpActive);
        if (winnerOurs) {
          score = C29.points(card) * 8 - C29.power(card);
        } else if (strength > bestStrength) {
          score = 1000 + C29.points(card) * 8 - strength;
        } else {
          score = -C29.points(card) * 8 - C29.power(card);
        }
      }
      _scores[i] = score;
    }
    // Insertion sort: there are never more than sixteen moves.
    for (var i = 1; i < count; i++) {
      final move = _m[out + i];
      final score = _scores[i];
      var j = i - 1;
      while (j >= 0 && _scores[j] < score) {
        _m[out + j + 1] = _m[out + j];
        _scores[j + 1] = _scores[j];
        j--;
      }
      _m[out + j + 1] = move;
      _scores[j + 1] = score;
    }
  }

  int _strength(int card, int led, bool trumpActive) {
    final suit = C29.suitOf(card);
    if (trumpActive && suit == rules.trump) return 100 + C29.power(card);
    if (suit == led) return C29.power(card);
    return -1;
  }

  /// The position at [to]: the one at [from] after [move].
  void _apply(int from, int to, int move) {
    for (var i = 0; i < positionSlots; i++) {
      _s[to + i] = _s[from + i];
    }
    final seat = _turn(to);
    final card = move & 31;
    final length = _s[to + _length];
    if (move & askFlag != 0) {
      _s[to + _revealed] = 1;
      // Trump counts from the asker's card on (AGENTS.md §6.9).
      _s[to + _trumpFrom] = length;
      final seventh = _s[to + _seventh];
      if (seventh >= 0) {
        _s[to + _hand0 + rules.bidder] |= 1 << seventh;
        _s[to + _seventh] = -1;
      }
    }
    if (card == _s[to + _seventh]) {
      // The seventh card played as the last card reveals trump, and counts.
      _s[to + _seventh] = -1;
      _s[to + _revealed] = 1;
      _s[to + _trumpFrom] = length;
    } else {
      _s[to + _hand0 + seat] &= ~(1 << card);
    }
    _s[to + _trick0 + length] = card;
    _s[to + _length] = length + 1;
    _s[to + _mustTrump] = -1;
    if (length + 1 == rules.trickSize) _finishTrick(to);
  }

  void _finishTrick(int b) {
    final led = C29.suitOf(_s[b + _trick0]);
    final trumpActive =
        _s[b + _revealed] != 0 && rules.trump >= 0 && rules.declarer < 0;
    final from = _s[b + _trumpFrom];
    var player = _s[b + _leader];
    var winner = player;
    var best = -2;
    var points = 0;
    for (var i = 0; i < rules.trickSize; i++) {
      final card = _s[b + _trick0 + i];
      points += C29.points(card);
      final strength = _strength(
        card,
        led,
        trumpActive && (i >= from || led == rules.trump),
      );
      if (strength > best) {
        best = strength;
        winner = player;
      }
      player = rules.seatAfter(player);
    }
    final done = _s[b + _done] + 1;
    _s[b + _done] = done;
    if (done == 8 && rules.lastTrickPoint && rules.declarer < 0) points++;
    if ((winner & 1) == rules.side) {
      _s[b + _sidePoints] += points;
    } else {
      _s[b + _otherPoints] += points;
      _s[b + _lost]++;
    }
    _s[b + _leader] = winner;
    _s[b + _length] = 0;
    _s[b + _trumpFrom] = _s[b + _revealed] != 0 ? 0 : Sim.noTrump;
  }

  /// Scores the position at [b], a trick boundary, by playing the rest of
  /// the deal out with the [Greedy] policy for every seat.
  int _playOut(int b) {
    final sim = Sim(
      hands: [for (var seat = 0; seat < 4; seat++) _s[b + _hand0 + seat]],
      trump: rules.trump,
      revealed: _s[b + _revealed] != 0,
      bidder: rules.declarer >= 0 ? rules.declarer : rules.bidder,
      leader: _s[b + _leader],
      declarer: rules.declarer,
      seventh: _s[b + _seventh],
      dutyToTrump: rules.dutyToTrump,
      mustAsk: rules.mustAsk,
      lastTrickPoint: rules.lastTrickPoint,
      tricksDone: _s[b + _done],
    );
    sim.points[rules.side] = _s[b + _sidePoints];
    sim.points[1 - rules.side] = _s[b + _otherPoints];
    sim.playOut();
    if (rules.declarer >= 0) {
      return sim.tricksWon[1 - rules.side] == 0
          ? DealValue.made
          : -DealValue.made;
    }
    final points = sim.points[rules.side];
    final tieBreak = points - 14;
    if (!sim.revealed) return tieBreak;
    return (points >= rules.target ? DealValue.made : -DealValue.made) +
        tieBreak;
  }
}
