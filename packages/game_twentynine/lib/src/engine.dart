import 'dart:math' as math;

import 'package:game_core/game_core.dart';

import 'actions.dart';
import 'auction.dart';
import 'config.dart';
import 'events.dart';
import 'rules.dart';
import 'state.dart';
import 'view.dart';

/// The rules of Twenty-Nine as played in Nepal (AGENTS.md §6), as a
/// deterministic reducer.
///
/// The same seed and the same actions always give the same state. Every
/// call returns a new state; nothing is changed in place.
final class TwentyNineGame
    implements
        GameDefinition<TwentyNineState, TwentyNineAction, TwentyNineView> {
  /// Creates the rules.
  const TwentyNineGame();

  /// The game's ID.
  static const String gameId = 'twentynine';

  @override
  String get id => gameId;

  @override
  int get rulesVersion => 1;

  @override
  List<Card> get deck => TwentyNineRules.deck;

  /// Starts a match. The first dealer and every shuffle come from [seed].
  ///
  /// Throws a [FormatException] if the rule options in [config] are invalid.
  @override
  TwentyNineState init(MatchConfig config, int seed) {
    final d = _newMatch(config, seed);
    d.dealer = Seat(
      Xoshiro256StarStar.seeded(_nextSeed(d))
          .nextBounded(TwentyNineRules.seatCount),
    );
    _startDeal(d);
    return d.toState();
  }

  /// Starts a match whose first deal uses [deck] in this order, dealt by
  /// [dealer]. Redeals and later deals shuffle from [seed]. For tests,
  /// tutorials and replays of known deals.
  ///
  /// Cards are dealt in fours from the start of [deck], first to the player
  /// after the dealer; the second four go round in the same order.
  TwentyNineState initWithDeck(
    MatchConfig config,
    int seed, {
    required Seat dealer,
    required List<Card> deck,
  }) {
    if (deck.length != TwentyNineRules.deck.length ||
        !deck.toSet().containsAll(TwentyNineRules.deck)) {
      throw ArgumentError.value(deck, 'deck', 'must hold each card once');
    }
    if (dealer.index >= TwentyNineRules.seatCount) {
      throw ArgumentError.value(dealer, 'dealer', 'must be seat 0 to 3');
    }
    final d = _newMatch(config, seed);
    _nextSeed(d); // Keeps later shuffles in step with init.
    d.dealer = dealer;
    _startDeal(d, firstDeck: deck);
    return d.toState();
  }

  @override
  List<TwentyNineAction> legalActions(TwentyNineState state, Seat seat) =>
      state.turn == seat ? _legal(state, seat) : const [];

  @override
  TwentyNineState apply(TwentyNineState state, TwentyNineAction action) {
    final seat = action.seat;
    if (state.isOver) {
      throw IllegalActionException(action, 'the match is over');
    }
    if (state.turn != seat) {
      throw IllegalActionException(action, 'it is not ${seat.id}\'s turn');
    }
    if (!_legal(state, seat).contains(action)) {
      throw IllegalActionException(action, 'not a legal action now');
    }
    final d = StateDraft.of(state)..events.add(ActionTaken(action));
    switch (action) {
      case Bid(:final value):
        _call(d, seat, value);
      case MatchBid(:final value):
        _call(d, seat, value);
      case Pass():
        _call(d, seat, null);
      case ChooseTrump(:final suit):
        d
          ..trumpMode = TrumpMode.suit
          ..trumpSuit = suit;
        _afterTrumpChosen(d);
      case CallSeventhCard():
        d.trumpMode = TrumpMode.seventhCard;
        _afterTrumpChosen(d);
      case Double():
        d
          ..doubledBy = seat
          ..phase = TwentyNinePhase.redoubling
          ..turn = d.bidder;
      case NoDouble():
        final firstOpponent = TwentyNineRules.next(d.bidder!);
        if (seat == firstOpponent) {
          d.turn = TwentyNineRules.partnerOf(firstOpponent);
        } else {
          _secondDeal(d);
        }
      case Redouble():
        d.redoubledBy = seat;
        _secondDeal(d);
      case NoRedouble():
        if (seat == d.bidder) {
          d.turn = TwentyNineRules.partnerOf(seat);
        } else {
          _secondDeal(d);
        }
      case DeclareSingleHand():
        _declareSingleHand(d, seat);
      case NoSingleHand():
        d.singleHandDeclines++;
        if (d.singleHandDeclines == TwentyNineRules.seatCount) {
          _startPlay(d, d.firstPlayer);
        } else {
          d.turn = TwentyNineRules.next(seat);
        }
      case PlayCard(:final card):
        _playCard(d, seat, card);
      case AskTrump():
        _revealTrump(d, seat);
        if (d.config.askTrump == AskTrumpRule.optional) d.mustTrump = seat;
      case DeclarePair():
        _declarePair(d, seat);
      case NoPair():
        d
          ..pairOffer = null
          ..phase = TwentyNinePhase.play
          ..turn = d.trickLeader;
    }
    return d.toState();
  }

  @override
  TwentyNineView viewFor(TwentyNineState state, Seat seat) =>
      TwentyNineView.of(state, seat, legalActions(state, seat));

  @override
  MatchResult? result(TwentyNineState state) {
    final team = state.winningTeam;
    if (team == null) return null;
    return MatchResult(
      winners: TwentyNineRules.seatsOf(team),
      details: {'winningTeam': team, 'scores': state.scores},
    );
  }

  // Legal actions.

  List<TwentyNineAction> _legal(TwentyNineState s, Seat seat) {
    switch (s.phase) {
      case TwentyNinePhase.auction:
        return _legalCalls(s, seat);
      case TwentyNinePhase.chooseTrump:
        return [
          for (final suit in Suit.values) ChooseTrump(seat, suit),
          if (s.config.seventhCard) CallSeventhCard(seat),
        ];
      case TwentyNinePhase.doubling:
        return [Double(seat), NoDouble(seat)];
      case TwentyNinePhase.redoubling:
        return [Redouble(seat), NoRedouble(seat)];
      case TwentyNinePhase.singleHand:
        return [DeclareSingleHand(seat), NoSingleHand(seat)];
      case TwentyNinePhase.pair:
        return [DeclarePair(seat), NoPair(seat)];
      case TwentyNinePhase.play:
        return _legalPlays(s, seat);
      case TwentyNinePhase.matchOver:
        return const [];
    }
  }

  /// A bid above the highest, a match for the old bidder facing the new
  /// one's bid, or a pass (AGENTS.md §6.4).
  List<TwentyNineAction> _legalCalls(TwentyNineState s, Seat seat) {
    final config = s.config;
    final position = AuctionPosition.of(s.calls, s.firstPlayer, config.maxBid);
    final high = position.high;
    if (position.alone && config.allPass == AllPassRule.dealerMustBid) {
      // The first three players passed; only the dealer is left.
      return [Bid(seat, config.minBid)];
    }
    final lowest = math.max(config.minBid, (high ?? 0) + 1);
    return [
      for (var value = lowest; value <= config.maxBid; value++)
        Bid(seat, value),
      if (position.mayMatch) MatchBid(seat, high!),
      Pass(seat),
    ];
  }

  List<TwentyNineAction> _legalPlays(TwentyNineState s, Seat seat) {
    final hand = s.hands[seat.index];
    List<TwentyNineAction> plays(Iterable<Card> cards) => [
      for (final card in cards) PlayCard(seat, card),
    ];
    // The bidder's set-aside seventh card may only be played as their last
    // card, which also reveals trump (AGENTS.md §6.5).
    if (hand.isEmpty) return [PlayCard(seat, s.seventhCard!)];
    if (s.trick.isEmpty) return plays(hand);
    if (s.mustTrump == seat) {
      final trumps = hand.where((card) => card.suit == s.trumpSuit);
      return plays(trumps.isEmpty ? hand : trumps);
    }
    final led = s.trick.first.card.suit;
    final following = hand.where((card) => card.suit == led);
    if (following.isNotEmpty) return plays(following);
    if (s.singleHandDeclarer != null || s.trumpRevealed) return plays(hand);
    // Cannot follow suit while trump is hidden (AGENTS.md §6.9).
    return switch (s.config.askTrump) {
      AskTrumpRule.optional => [...plays(hand), AskTrump(seat)],
      AskTrumpRule.mandatory => [AskTrump(seat)],
    };
  }

  // Dealing.

  StateDraft _newMatch(MatchConfig config, int seed) =>
      StateDraft.newMatch(TwentyNineConfig.fromMatchConfig(config), seed);

  /// The next value of the match's seed stream: SplitMix64 of the match
  /// seed, one value for the first dealer, then one per shuffle.
  int _nextSeed(StateDraft d) {
    final stream = SplitMix64(d.matchSeed);
    var value = stream.next();
    for (var i = 0; i < d.seedsUsed; i++) {
      value = stream.next();
    }
    d.seedsUsed++;
    return value;
  }

  /// Shuffles and deals the first four cards to each player, repeating while
  /// redeal check A cancels the deal (AGENTS.md §6.3 and §6.7).
  void _startDeal(StateDraft d, {List<Card>? firstDeck}) {
    var given = firstDeck;
    for (;;) {
      final int? seed;
      final List<Card> order;
      if (given != null) {
        seed = null;
        order = List.of(given);
        given = null;
      } else {
        seed = _nextSeed(d);
        order = List.of(TwentyNineRules.deck);
        shuffleInPlace(order, Xoshiro256StarStar.seeded(seed));
      }
      d
        ..resetDeal()
        ..dealSeed = seed;
      for (var i = 0; i < TwentyNineRules.seatCount; i++) {
        final seat = d.firstPlayer.offset(i, TwentyNineRules.seatCount);
        d.hands[seat.index] = order.sublist(i * 4, i * 4 + 4);
      }
      d
        ..undealt = order.sublist(16)
        ..events.add(
          DealStarted(
            dealNumber: d.dealNumber,
            dealer: d.dealer,
            seed: seed,
            deck: seed == null ? List.unmodifiable(order) : null,
          ),
        );
      final firstHand = d.hands[d.firstPlayer.index];
      if (d.config.redealChecks &&
          !firstHand.any(TwentyNineRules.isPointCard)) {
        d.events.add(
          const DealCancelled(DealCancelReason.firstPlayerNoPointCards),
        );
        continue;
      }
      d
        ..phase = TwentyNinePhase.auction
        ..turn = d.firstPlayer;
      return;
    }
  }

  /// Deals the second four cards, sets aside a called seventh card, and
  /// runs redeal check B.
  void _secondDeal(StateDraft d) {
    for (var i = 0; i < TwentyNineRules.seatCount; i++) {
      final seat = d.firstPlayer.offset(i, TwentyNineRules.seatCount);
      d.hands[seat.index].addAll(d.undealt.sublist(i * 4, i * 4 + 4));
    }
    d.undealt = [];
    final bidder = d.bidder!;
    if (d.trumpMode == TrumpMode.seventhCard) {
      // The third card of the second batch: the seventh card overall.
      final card = d.hands[bidder.index].removeAt(6);
      d
        ..seventhCard = card
        ..seventhCardSetAside = true
        ..trumpSuit = card.suit;
    }
    if (d.config.redealChecks) {
      final reason = _redealCheckB(d);
      if (reason != null) {
        d.events.add(DealCancelled(reason));
        _startDeal(d);
        return;
      }
    }
    if (d.config.singleHand) {
      d
        ..phase = TwentyNinePhase.singleHand
        ..turn = d.firstPlayer;
    } else {
      _startPlay(d, d.firstPlayer);
    }
  }

  DealCancelReason? _redealCheckB(StateDraft d) {
    for (var i = 0; i < TwentyNineRules.seatCount; i++) {
      final cards = [
        ...d.hands[i],
        if (d.seventhCardSetAside && d.bidder!.index == i) d.seventhCard!,
      ];
      if (!cards.any(TwentyNineRules.isPointCard)) {
        return DealCancelReason.playerNoPointCards;
      }
      if (cards.where((card) => card.rank == Rank.jack).length == 4) {
        return DealCancelReason.allFourJacks;
      }
      if (cards.every((card) => card.suit == cards.first.suit)) {
        return DealCancelReason.eightOfOneSuit;
      }
    }
    return null;
  }

  // Auction.

  /// Records [seat]'s call: a bid or match of [value], or a pass when it is
  /// null. Then the auction goes on with the seat [AuctionPosition] gives,
  /// or ends (AGENTS.md §6.4).
  void _call(StateDraft d, Seat seat, int? value) {
    d.calls.add(AuctionCall(seat, value));
    if (value != null) {
      d
        ..highBid = value
        ..highBidder = seat;
    }
    final position = AuctionPosition.of(
      d.calls,
      d.firstPlayer,
      d.config.maxBid,
    );
    if (position.allPassed) {
      d.events.add(const DealCancelled(DealCancelReason.allPassed));
      _startDeal(d);
    } else if (position.over) {
      _endAuction(d, position.holder!, position.high!);
    } else {
      d.turn = position.turn;
    }
  }

  void _endAuction(StateDraft d, Seat bidder, int contract) {
    d
      ..bidder = bidder
      ..contract = contract
      ..target = contract
      ..events.add(AuctionWon(bidder, contract))
      ..phase = TwentyNinePhase.chooseTrump
      ..turn = bidder;
  }

  void _afterTrumpChosen(StateDraft d) {
    if (d.config.doubleRedouble) {
      d
        ..phase = TwentyNinePhase.doubling
        ..turn = TwentyNineRules.next(d.bidder!);
    } else {
      _secondDeal(d);
    }
  }

  void _declareSingleHand(StateDraft d, Seat seat) {
    d.singleHandDeclarer = seat;
    // There is no trump, so a set-aside seventh card goes back in the hand.
    if (d.seventhCardSetAside) {
      d.hands[d.bidder!.index].add(d.seventhCard!);
      d.seventhCardSetAside = false;
    }
    _startPlay(d, seat);
  }

  // Play.

  void _startPlay(StateDraft d, Seat leader) {
    d
      ..phase = TwentyNinePhase.play
      ..trickLeader = leader
      ..trick = []
      ..turn = leader;
  }

  void _playCard(StateDraft d, Seat seat, Card card) {
    if (d.seventhCardSetAside && card == d.seventhCard) {
      // Playing the seventh card as the last card reveals trump.
      d.seventhCardSetAside = false;
      _revealTrump(d, seat);
    } else {
      d.hands[seat.index].remove(card);
    }
    d.trick.add(TrickPlay(seat, card));
    if (d.mustTrump == seat) d.mustTrump = null;
    final trickSize = d.singleHandDeclarer == null ? 4 : 3;
    if (d.trick.length == trickSize) {
      _finishTrick(d);
    } else {
      d.turn = _nextToPlay(d, seat);
    }
  }

  /// Shows trump to everyone. A set-aside seventh card joins the bidder's
  /// hand.
  void _revealTrump(StateDraft d, Seat revealedBy) {
    if (d.seventhCardSetAside) {
      d.hands[d.bidder!.index].add(d.seventhCard!);
      d.seventhCardSetAside = false;
    }
    d
      ..trumpRevealed = true
      ..revealTrick = d.tricks.length
      ..revealedBy = revealedBy
      ..events.add(
        TrumpRevealed(
          revealedBy,
          d.trumpSuit!,
          seventhCard: d.trumpMode == TrumpMode.seventhCard
              ? d.seventhCard
              : null,
        ),
      );
  }

  /// The next player to play after [seat]; in single hand the declarer's
  /// partner is skipped.
  Seat _nextToPlay(StateDraft d, Seat seat) {
    var next = TwentyNineRules.next(seat);
    final declarer = d.singleHandDeclarer;
    if (declarer != null && next == TwentyNineRules.partnerOf(declarer)) {
      next = TwentyNineRules.next(next);
    }
    return next;
  }

  void _finishTrick(StateDraft d) {
    final plays = List<TrickPlay>.unmodifiable(d.trick);
    final winner = _trickWinner(d, plays);
    final points = plays.fold(
      0,
      (sum, play) => sum + TwentyNineRules.points(play.card),
    );
    final team = TwentyNineRules.teamOf(winner);
    d
      ..tricks.add(
        Trick(
          leader: d.trickLeader!,
          plays: plays,
          winner: winner,
          points: points,
        ),
      )
      ..cardPoints[team] += points
      ..events.add(TrickWon(winner, d.tricks.length, points))
      ..trick = []
      ..mustTrump = null
      ..trickLeader = winner;

    final declarer = d.singleHandDeclarer;
    if (declarer != null) {
      // Single hand ends as soon as the declarer loses a trick.
      if (winner != declarer) {
        _scoreSingleHand(d, won: false);
      } else if (d.tricks.length == TwentyNineRules.tricksPerDeal) {
        _scoreSingleHand(d, won: true);
      } else {
        d.turn = winner;
      }
      return;
    }
    if (d.tricks.length == TwentyNineRules.tricksPerDeal) {
      if (d.config.lastTrickPoint) d.cardPoints[team] += 1;
      _scoreDeal(d);
      return;
    }
    final pairHolder = _pairHolder(d, winner);
    if (pairHolder != null) {
      d
        ..pairOffer = pairHolder
        ..phase = TwentyNinePhase.pair
        ..turn = pairHolder;
    } else {
      d.turn = winner;
    }
  }

  /// The player of [winner]'s team who may declare the Pair now, if any
  /// (AGENTS.md §6.10).
  Seat? _pairHolder(StateDraft d, Seat winner) {
    if (!d.config.pair || d.pairBy != null || !d.trumpRevealed) return null;
    final king = Card(Rank.king, d.trumpSuit!);
    final queen = Card(Rank.queen, d.trumpSuit!);
    for (final seat in [winner, TwentyNineRules.partnerOf(winner)]) {
      final hand = d.hands[seat.index];
      if (hand.contains(king) && hand.contains(queen)) return seat;
    }
    return null;
  }

  /// The highest trump played once trump was revealed, otherwise the
  /// highest card of the suit led (AGENTS.md §6.9). A trump-suit card played
  /// on another suit before the reveal is a plain card, even in the trick in
  /// which trump is revealed: there, trump counts from the revealer's own
  /// card on, which is the card played after asking, or the seventh card
  /// whose play reveals trump. When trump itself is led, every card of it
  /// follows suit, so the highest wins whenever trump was revealed.
  Seat _trickWinner(StateDraft d, List<TrickPlay> plays) {
    final led = plays.first.card.suit;
    final trump = d.singleHandDeclarer == null && d.trumpRevealed
        ? d.trumpSuit
        : null;
    final from =
        trump != null && trump != led && d.revealTrick == d.tricks.length
        ? plays.indexWhere((play) => play.seat == d.revealedBy)
        : 0;
    int strength(int position) {
      final card = plays[position].card;
      final power = TwentyNineRules.power(card.rank);
      if (card.suit == trump && position >= from) return 100 + power;
      if (card.suit == led) return power;
      return -1;
    }

    var best = 0;
    for (var position = 1; position < plays.length; position++) {
      if (strength(position) > strength(best)) best = position;
    }
    return plays[best].seat;
  }

  void _declarePair(StateDraft d, Seat seat) {
    final contract = d.contract!;
    final config = d.config;
    final bidderTeam = TwentyNineRules.teamOf(d.bidder!);
    final target = TwentyNineRules.teamOf(seat) == bidderTeam
        ? math.max(config.minBid, contract - 4)
        : math.min(config.maxBid, contract + 4);
    d
      ..pairBy = seat
      ..pairOffer = null
      ..target = target
      ..events.add(TargetChanged(target))
      ..phase = TwentyNinePhase.play
      ..turn = d.trickLeader;
  }

  // Scoring.

  void _scoreDeal(StateDraft d) {
    final team = TwentyNineRules.teamOf(d.bidder!);
    final target = d.target!;
    final stake = d.stake;
    final DealOutcome outcome;
    final int delta;
    if (!d.trumpRevealed) {
      outcome = DealOutcome.voided;
      delta = 0;
    } else if (d.cardPoints[team] >= target) {
      outcome = DealOutcome.contractMade;
      delta = stake;
    } else {
      outcome = DealOutcome.contractFailed;
      delta = -stake;
    }
    d.scores[team] += delta;
    d.events.add(
      DealScored(
        outcome: outcome,
        team: team,
        delta: delta,
        stake: stake,
        target: target,
        teamPoints: List.unmodifiable(d.cardPoints),
        scores: List.unmodifiable(d.scores),
      ),
    );
    _afterDeal(d);
  }

  void _scoreSingleHand(StateDraft d, {required bool won}) {
    final team = TwentyNineRules.teamOf(d.singleHandDeclarer!);
    final stake = d.stake;
    final delta = won ? stake : -stake;
    d.scores[team] += delta;
    d.events.add(
      DealScored(
        outcome: won ? DealOutcome.singleHandWon : DealOutcome.singleHandLost,
        team: team,
        delta: delta,
        stake: stake,
        teamPoints: List.unmodifiable(d.cardPoints),
        scores: List.unmodifiable(d.scores),
      ),
    );
    _afterDeal(d);
  }

  /// Ends the match at the target, or passes the deal to the next player.
  void _afterDeal(StateDraft d) {
    final target = d.config.targetGamePoints;
    int? winner;
    for (var team = 0; team < 2; team++) {
      if (d.scores[team] >= target) winner = team;
      if (d.scores[team] <= -target) winner = 1 - team;
    }
    if (winner != null) {
      d
        ..phase = TwentyNinePhase.matchOver
        ..turn = null
        ..winningTeam = winner
        ..events.add(MatchEnded(winner, List.unmodifiable(d.scores)));
      return;
    }
    d
      ..dealer = TwentyNineRules.next(d.dealer)
      ..dealNumber += 1;
    _startDeal(d);
  }
}
