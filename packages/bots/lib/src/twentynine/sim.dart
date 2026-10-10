import 'cards.dart';

/// A deal of Twenty-Nine with every hand known, played out quickly inside a
/// bot: the rest of one trick for the Skilled lookahead, or a whole deal for
/// Monte Carlo bidding.
///
/// It follows the engine's rules for following suit, asking for trump, the
/// seventh card and winning tricks. It leaves out the Pair, which moves the
/// target rather than the points.
final class Sim {
  /// Creates a simulation from a known position.
  Sim({
    required this.hands,
    required this.trump,
    required this.revealed,
    required this.bidder,
    required this.leader,
    this.declarer = -1,
    this.seventh = -1,
    this.dutyToTrump = true,
    this.mustAsk = false,
    this.lastTrickPoint = true,
    this.played = 0,
    this.tricksDone = 0,
    int? trumpFrom,
  }) : trumpFrom = trumpFrom ?? (revealed ? 0 : noTrump);

  /// [trumpFrom] while trump has no power in the current trick.
  static const int noTrump = 4;

  /// The position in the current trick from which trump-suit cards are
  /// trumps: 0 when trump was revealed before the trick, the revealer's
  /// position when it was revealed during it, [noTrump] while it is hidden.
  /// A trump-suit card played on another suit before the reveal is a plain
  /// card, even in the trick in which trump is revealed; when trump itself
  /// is led, every card of it counts (AGENTS.md §6.9).
  int trumpFrom;

  /// Each seat's cards. A set-aside seventh card is in [seventh] instead.
  final List<int> hands;

  /// The trump suit, or -1 when there is none.
  final int trump;

  /// Whether trump has been revealed.
  bool revealed;

  /// The bidder's seat.
  final int bidder;

  /// The single-hand declarer's seat, or -1.
  final int declarer;

  /// The bidder's set-aside seventh card, or -1.
  int seventh;

  /// Whether a player who asks for trump must then trump if able.
  final bool dutyToTrump;

  /// Whether a player who cannot follow suit must ask for hidden trump.
  final bool mustAsk;

  /// Whether the last trick is worth a point.
  final bool lastTrickPoint;

  /// Every card played in the deal so far, the current trick included.
  int played;

  /// Finished tricks in the deal.
  int tricksDone;

  /// Card points won by each team.
  final List<int> points = [0, 0];

  /// Tricks won by each team since the simulation began.
  final List<int> tricksWon = [0, 0];

  /// The player who leads, or led, the current trick.
  int leader;

  /// The seats that have played to the current trick, in order.
  final List<int> trickSeats = [0, 0, 0, 0];

  /// The cards played to the current trick, in order.
  final List<int> trickCards = [0, 0, 0, 0];

  /// How many cards are on the current trick.
  int trickLength = 0;

  /// A player who asked for trump in this trick and must trump if able.
  int mustTrump = -1;

  /// The winner of the last finished trick, or -1.
  int lastWinner = -1;

  /// Cards to a trick: three in single hand, four otherwise.
  int get trickSize => declarer >= 0 ? 3 : 4;

  /// The seat to play next.
  int get turn =>
      trickLength == 0 ? leader : nextSeat(trickSeats[trickLength - 1]);

  /// Whether all eight tricks are finished.
  bool get over => tricksDone == 8;

  /// The team of [seat].
  static int team(int seat) => seat & 1;

  /// The seat after [seat], skipping a single-hand declarer's partner.
  int nextSeat(int seat) {
    var next = (seat + 1) & 3;
    if (declarer >= 0 && next == ((declarer + 2) & 3)) next = (next + 1) & 3;
    return next;
  }

  /// The suit led to the current trick. Only valid while it has cards.
  int get ledSuit => C29.suitOf(trickCards[0]);

  /// Whether trump cards win tricks now.
  bool get trumpActive => revealed && trump >= 0 && declarer < 0;

  /// Puts a card that was played before the simulation began on the
  /// current trick.
  void addToTrick(int seat, int card) {
    trickSeats[trickLength] = seat;
    trickCards[trickLength] = card;
    trickLength++;
  }

  /// The strength of the card at [position] in the current trick.
  int _strength(int position, int led) {
    final card = trickCards[position];
    final suit = C29.suitOf(card);
    if (trumpActive &&
        suit == trump &&
        (position >= trumpFrom || led == trump)) {
      return 100 + C29.power(card);
    }
    if (suit == led) return C29.power(card);
    return -1;
  }

  /// Whether the play winning the current trick so far is a trump.
  bool winningIsTrump() =>
      trickLength > 0 && _strength(winningPosition(), ledSuit) >= 100;

  /// The position in the current trick of the play winning it so far.
  int winningPosition() {
    final led = ledSuit;
    var best = 0;
    var bestStrength = _strength(0, led);
    for (var i = 1; i < trickLength; i++) {
      final strength = _strength(i, led);
      if (strength > bestStrength) {
        best = i;
        bestStrength = strength;
      }
    }
    return best;
  }

  /// The card points on the current trick.
  int trickPoints() {
    var total = 0;
    for (var i = 0; i < trickLength; i++) {
      total += C29.points(trickCards[i]);
    }
    return total;
  }

  /// The cards [seat] may play now; asking for trump is separate.
  int legal(int seat) {
    final hand = hands[seat];
    if (hand == 0) return seat == bidder && seventh >= 0 ? 1 << seventh : 0;
    if (trickLength == 0) return hand;
    if (mustTrump == seat) {
      final trumps = hand & C29.suitMask(trump);
      return trumps != 0 ? trumps : hand;
    }
    final following = hand & C29.suitMask(ledSuit);
    return following != 0 ? following : hand;
  }

  /// Whether [seat] may ask for trump now.
  bool canAsk(int seat) =>
      trickLength > 0 &&
      !revealed &&
      declarer < 0 &&
      trump >= 0 &&
      mustTrump != seat &&
      hands[seat] != 0 &&
      hands[seat] & C29.suitMask(ledSuit) == 0;

  /// [seat] asks for trump.
  void ask(int seat) {
    _reveal();
    if (dutyToTrump) mustTrump = seat;
  }

  void _reveal() {
    revealed = true;
    // Trump counts from the card played now on.
    trumpFrom = trickLength;
    if (seventh >= 0) {
      hands[bidder] |= 1 << seventh;
      seventh = -1;
    }
  }

  /// [seat] plays [card]; finishes the trick when it is full.
  void play(int seat, int card) {
    if (card == seventh) {
      // The seventh card played as the last card reveals trump, and counts.
      seventh = -1;
      revealed = true;
      trumpFrom = trickLength;
    } else {
      hands[seat] &= ~(1 << card);
    }
    played |= 1 << card;
    addToTrick(seat, card);
    if (mustTrump == seat) mustTrump = -1;
    if (trickLength == trickSize) _finishTrick();
  }

  void _finishTrick() {
    final winner = trickSeats[winningPosition()];
    var won = trickPoints();
    tricksDone++;
    if (tricksDone == 8 && lastTrickPoint && declarer < 0) won += 1;
    points[team(winner)] += won;
    tricksWon[team(winner)]++;
    lastWinner = winner;
    leader = winner;
    trickLength = 0;
    mustTrump = -1;
    trumpFrom = revealed ? 0 : noTrump;
  }

  /// Whether no card of [card]'s suit that could still be played is
  /// stronger.
  bool isMaster(int card) {
    final suit = C29.suitOf(card);
    var others = seventh >= 0 ? 1 << seventh : 0;
    for (final hand in hands) {
      others |= hand;
    }
    others &= C29.suitMask(suit) & ~(1 << card);
    for (var i = suit * 8; i < suit * 8 + 8; i++) {
      if (others & (1 << i) != 0 && C29.power(i) > C29.power(card)) {
        return false;
      }
    }
    return true;
  }

  /// Whether the play winning the current trick will still win it after
  /// the players who play after [seat], given everyone's cards. [seat] is
  /// the player about to play.
  bool winnerIsSafeAfter(int seat) {
    final best = trickCards[winningPosition()];
    final bestSuit = C29.suitOf(best);
    final bestIsTrump = winningIsTrump();
    final led = ledSuit;
    var next = nextSeat(seat);
    for (var left = trickSize - trickLength - 1; left > 0; left--) {
      final player = next;
      final hand = hands[player];
      final following = hand & C29.suitMask(led);
      if (following != 0) {
        if (bestSuit == led && _beats(following, best)) return false;
      } else if (trump >= 0 && declarer < 0) {
        // Revealed or not, a player with no card of the suit led can trump:
        // while trump is hidden they can ask first.
        final trumps = hand & C29.suitMask(trump);
        if (trumps != 0) {
          if (!bestIsTrump || _beats(trumps, best)) {
            return false;
          }
        }
      }
      next = nextSeat(player);
    }
    return true;
  }

  static bool _beats(int mask, int card) {
    final suit = C29.suitOf(card);
    final top = C29.strongest(mask, suit);
    return top >= 0 && C29.power(top) > C29.power(card);
  }

  /// Plays the current trick to its end with [Greedy] play.
  void finishTrick() {
    final done = tricksDone;
    while (tricksDone == done) {
      Greedy.move(this);
    }
  }

  /// Plays the rest of the deal with [Greedy] play.
  void playOut() {
    while (!over) {
      Greedy.move(this);
    }
  }
}

/// A quick, sensible way of playing used for every seat in a [Sim]: win a
/// trick cheaply from the opponents, feed points to a partner who is sure
/// to win, lead cards nobody can beat, and ask for trump when a trick is
/// worth it.
abstract final class Greedy {
  /// Plays one card for the seat to act, asking for trump first when it
  /// wants to.
  static void move(Sim sim) {
    final seat = sim.turn;
    sim.play(seat, choose(sim, seat));
  }

  /// The card [seat] plays now. May ask for trump first.
  static int choose(Sim sim, int seat) {
    final legal = sim.legal(seat);
    if (sim.trickLength == 0) {
      return legal & (legal - 1) == 0 ? legal.bitLength - 1 : _lead(sim, legal);
    }
    final following = sim.hands[seat] & C29.suitMask(sim.ledSuit);
    if (following != 0 && sim.mustTrump != seat) {
      return _follow(sim, seat, following);
    }
    if (sim.canAsk(seat) && (sim.mustAsk || _wantsTrump(sim, seat))) {
      sim.ask(seat);
      return _cannotFollow(sim, seat, sim.legal(seat));
    }
    if (legal & (legal - 1) == 0) return legal.bitLength - 1;
    return _cannotFollow(sim, seat, legal);
  }

  static int _lead(Sim sim, int legal) {
    final seat = sim.turn;
    // The bidding side draws trumps with a trump nobody can beat.
    if (sim.trumpActive && Sim.team(seat) == Sim.team(sim.bidder)) {
      final top = C29.strongest(legal, sim.trump);
      if (top >= 0 && sim.isMaster(top)) return top;
    }
    // A plain card nobody can beat wins unless someone trumps it.
    var best = -1;
    for (var suit = 0; suit < 4; suit++) {
      if (sim.trumpActive && suit == sim.trump) continue;
      final top = C29.strongest(legal, suit);
      if (top >= 0 &&
          sim.isMaster(top) &&
          (best < 0 || C29.points(top) > C29.points(best))) {
        best = top;
      }
    }
    if (best >= 0) return best;
    // Otherwise the cheapest card of the longest plain suit.
    var longest = -1;
    var length = 0;
    for (var suit = 0; suit < 4; suit++) {
      if (sim.trumpActive && suit == sim.trump) continue;
      final count = C29.count(legal & C29.suitMask(suit));
      if (count > length) {
        longest = suit;
        length = count;
      }
    }
    final pool = longest >= 0 ? legal & C29.suitMask(longest) : legal;
    return C29.cheapest(pool);
  }

  static int _follow(Sim sim, int seat, int following) {
    final position = sim.winningPosition();
    final winner = sim.trickSeats[position];
    final best = sim.trickCards[position];
    final last = sim.trickLength == sim.trickSize - 1;
    if (Sim.team(winner) == Sim.team(seat)) {
      return last || sim.winnerIsSafeAfter(seat)
          ? C29.richest(following)
          : C29.cheapest(following);
    }
    if (C29.suitOf(best) == sim.ledSuit) {
      final beaters = _stronger(following, best);
      if (beaters != 0) {
        final suit = sim.ledSuit;
        if (last) return C29.weakest(beaters, suit);
        final top = C29.strongest(beaters, suit);
        if (sim.isMaster(top)) return top;
        if (sim.trickPoints() >= 2) return C29.weakest(beaters, suit);
      }
    }
    return C29.cheapest(following);
  }

  static bool _wantsTrump(Sim sim, int seat) {
    final position = sim.winningPosition();
    if (Sim.team(sim.trickSeats[position]) == Sim.team(seat)) return false;
    final value = sim.trickPoints();
    if (seat == sim.bidder) {
      return value >= 1 && sim.hands[seat] & C29.suitMask(sim.trump) != 0;
    }
    return value >= 2 || C29.power(sim.trickCards[position]) >= 5;
  }

  static int _cannotFollow(Sim sim, int seat, int legal) {
    final position = sim.winningPosition();
    final partnerWinning = Sim.team(sim.trickSeats[position]) == Sim.team(seat);
    final trumps = sim.trumpActive ? legal & C29.suitMask(sim.trump) : 0;
    if (!partnerWinning && trumps != 0) {
      final best = sim.trickCards[position];
      final winners = sim.winningIsTrump() ? _stronger(trumps, best) : trumps;
      if (winners != 0 &&
          (sim.trickPoints() >= 1 ||
              sim.mustTrump == seat ||
              sim.tricksDone >= 6)) {
        return C29.weakest(winners, sim.trump);
      }
    }
    if (sim.mustTrump == seat && trumps != 0) {
      return C29.weakest(trumps, sim.trump);
    }
    final plain = trumps != 0 ? legal & ~C29.suitMask(sim.trump) : legal;
    final pool = plain != 0 ? plain : legal;
    return partnerWinning && sim.winnerIsSafeAfter(seat)
        ? C29.richest(pool)
        : C29.cheapest(pool);
  }

  /// The cards of [mask] in [card]'s suit that beat it.
  static int _stronger(int mask, int card) {
    final suit = C29.suitOf(card);
    var result = 0;
    for (var i = suit * 8; i < suit * 8 + 8; i++) {
      if (mask & (1 << i) != 0 && C29.power(i) > C29.power(card)) {
        result |= 1 << i;
      }
    }
    return result;
  }
}
