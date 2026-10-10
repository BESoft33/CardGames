import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';

import '../bot.dart';
import 'beliefs.dart';
import 'cards.dart';
import 'ismcts.dart';
import 'knowledge.dart';
import 'search.dart';
import 'sim.dart';

/// A computer player for Twenty-Nine at one [BotLevel] (AGENTS.md §8.4).
///
/// It decides from its seat's view alone, with the context's random numbers
/// and budget. It keeps nothing between decisions, so the same view, seed
/// and budget always give the same decision.
final class TwentyNineBot
    implements BotPolicy<TwentyNineView, TwentyNineAction> {
  /// A bot of [level].
  TwentyNineBot(BotLevel level) : settings = level.settings;

  /// A bot with the given knobs, for tests and tuning.
  const TwentyNineBot.withSettings(this.settings);

  /// The bot's knobs.
  final BotSettings settings;

  @override
  TwentyNineAction decide(TwentyNineView view, BotContext context) {
    final legal = view.legalActions;
    if (legal.isEmpty) {
      throw StateError('${view.seat.id} has no decision to make');
    }
    if (legal.length == 1) return legal.single;
    return switch (view.phase) {
      TwentyNinePhase.auction => _bid(view, context),
      TwentyNinePhase.chooseTrump => _chooseTrump(view, context),
      TwentyNinePhase.doubling => _double(view, context),
      TwentyNinePhase.redoubling => _redouble(view, context),
      TwentyNinePhase.singleHand => _singleHand(view),
      // Always declare a Pair (AGENTS.md §8.3).
      TwentyNinePhase.pair => DeclarePair(view.seat),
      TwentyNinePhase.play => _play(view, context),
      TwentyNinePhase.matchOver => throw StateError('the match is over'),
    };
  }

  bool get _searches => settings.searchBudget > 0;

  bool _isPartner(TwentyNineView view, Seat? seat) =>
      seat != null &&
      seat != view.seat &&
      TwentyNineRules.teamOf(seat) == TwentyNineRules.teamOf(view.seat);

  // Bidding.

  /// Bids up to the bot's limit: as the old bidder it matches the new
  /// bidder's bid, which keeps the contract lowest; otherwise it raises by
  /// one; above its limit it passes (AGENTS.md §6.4).
  TwentyNineAction _bid(TwentyNineView view, BotContext context) {
    final bids = view.legalActions.whereType<Bid>().map((bid) => bid.value);
    final lowest = bids.isEmpty ? null : bids.reduce(math.min);
    final match = view.legalActions.whereType<MatchBid>().firstOrNull;
    final limit = _searches && context.budget > 0
        ? _monteCarloLimit(view, context)
        : settings.memory == BotMemory.none
        ? _tableLimit(view.hand)
        : _estimateLimit(view.hand);
    final highBid = view.highBid;
    // A partner already holds the bid: only go over with a clearly better
    // hand.
    final overPartner =
        _isPartner(view, view.highBidder) &&
        highBid != null &&
        limit < highBid + 2;
    final pass = Pass(view.seat);
    if (!overPartner) {
      if (match != null && limit >= match.value) return match;
      if (lowest != null && limit >= lowest) return Bid(view.seat, lowest);
    }
    if (view.legalActions.contains(pass)) return pass;
    return lowest != null ? Bid(view.seat, lowest) : match!;
  }

  /// Beginner: the highest bid allowed by a point-count table.
  static int _tableLimit(List<Card> hand) {
    final points = hand.map(TwentyNineRules.points).fold(0, (a, b) => a + b);
    final longest = Suit.values
        .map((suit) => hand.where((card) => card.suit == suit).length)
        .reduce(math.max);
    final hasJack = hand.any((card) => card.rank == Rank.jack);
    if (points >= 7) return 18;
    if (points >= 5 && longest >= 2) return 17;
    if (points >= 3 && longest >= 2 && hasJack) return 16;
    return 0;
  }

  /// Casual: points the team can expect with [trump], from the bot's cards.
  static double _estimate(List<Card> hand, Suit trump) {
    var estimate = 11.0;
    for (final card in hand) {
      final points = TwentyNineRules.points(card);
      if (card.suit == trump) {
        estimate += 1.0 + 0.8 * points;
        if (card.rank == Rank.jack) estimate += 1.5;
        if (card.rank == Rank.nine) estimate += 0.8;
      } else {
        estimate += 0.6 * points;
      }
    }
    return estimate;
  }

  static Suit _bestEstimateSuit(List<Card> hand) => Suit.values.reduce(
    (a, b) => _estimate(hand, b) > _estimate(hand, a) ? b : a,
  );

  static int _estimateLimit(List<Card> hand) =>
      (_estimate(hand, _bestEstimateSuit(hand)) - 0.5).floor();

  /// Skilled: the highest bid the bot makes in at least the risk-threshold
  /// share of sampled deals, with the best trump.
  int _monteCarloLimit(TwentyNineView view, BotContext context) {
    final deals = _sampleDeals(view, context);
    var limit = 0;
    for (var suit = 0; suit < 4; suit++) {
      final points = _playouts(view, deals, view.seat.index, (_) => suit);
      limit = math.max(
        limit,
        _confidentBid(points, view.config, settings.riskThreshold),
      );
    }
    return limit;
  }

  static int _confidentBid(
    List<int> points,
    TwentyNineConfig config,
    double threshold,
  ) {
    var best = 0;
    for (var bid = config.minBid; bid <= config.maxBid; bid++) {
      final made = points.where((p) => p >= bid).length;
      if (made >= threshold * points.length) best = bid;
    }
    return best;
  }

  /// Deals for Monte Carlo play before the second deal: the bot's own four
  /// cards are fixed; everything else, its own second four included, is
  /// dealt at random. With beliefs on, four times as many are dealt and
  /// kept in proportion to how well they fit the auction (AGENTS.md §8.3.1).
  List<List<int>> _sampleDeals(TwentyNineView view, BotContext context) {
    final me = view.seat.index;
    final mine = C29.maskOf(view.hand);
    final unseen = C29.list(0xFFFFFFFF & ~mine);
    final count = settings.biddingSamples > 0
        ? settings.biddingSamples
        : context.budget;
    if (!settings.beliefs) {
      return [
        for (var i = 0; i < count; i++)
          _dealUnseen(unseen, me, mine, context.random),
      ];
    }
    final beliefs = Beliefs(
      view,
      Knowledge.of(view, inference: settings.inference),
      soft: true,
    );
    final pool = [
      for (var i = 0; i < count * 4; i++)
        _dealUnseen(unseen, me, mine, context.random),
    ];
    final weights = [for (final deal in pool) beliefs.auctionFit(deal, -1)];
    final total = weights.fold(0.0, (a, b) => a + b);
    return [
      for (var i = 0; i < count; i++)
        () {
          var pick = unitRandom(context.random) * total;
          for (final (j, weight) in weights.indexed) {
            pick -= weight;
            if (pick < 0) return pool[j];
          }
          return pool.last;
        }(),
    ];
  }

  static List<int> _dealUnseen(
    List<int> unseen,
    int me,
    int mine,
    Xoshiro256StarStar random,
  ) {
    final cards = List.of(unseen);
    shuffleInPlace(cards, random);
    final hands = [0, 0, 0, 0];
    hands[me] = mine;
    var next = 0;
    for (var seat = 0; seat < 4; seat++) {
      final need = 8 - C29.count(hands[seat]);
      for (var i = 0; i < need; i++) {
        hands[seat] |= 1 << cards[next++];
      }
    }
    return hands;
  }

  /// The bidding team's card points in each of [deals], played out with
  /// [bidder] bidding and trump chosen by [trumpOf].
  static List<int> _playouts(
    TwentyNineView view,
    List<List<int>> deals,
    int bidder,
    int Function(List<int> hands) trumpOf,
  ) {
    final config = view.config;
    return [
      for (final deal in deals)
        () {
          final sim = Sim(
            hands: List.of(deal),
            trump: trumpOf(deal),
            revealed: false,
            bidder: bidder,
            leader: view.firstPlayer.index,
            dutyToTrump: config.askTrump == AskTrumpRule.optional,
            mustAsk: config.askTrump == AskTrumpRule.mandatory,
            lastTrickPoint: config.lastTrickPoint,
          )..playOut();
          return sim.points[Sim.team(bidder)];
        }(),
    ];
  }

  // Trump.

  TwentyNineAction _chooseTrump(TwentyNineView view, BotContext context) {
    final Suit suit;
    if (_searches && context.budget > 0) {
      final deals = _sampleDeals(view, context);
      final contract = view.contract!;
      var bestSuit = 0;
      var bestScore = -1.0;
      for (var s = 0; s < 4; s++) {
        final points = _playouts(view, deals, view.seat.index, (_) => s);
        final made = points.where((p) => p >= contract).length;
        final mean = points.fold(0, (a, b) => a + b) / points.length;
        final score = made * 100.0 + mean;
        if (score > bestScore) {
          bestSuit = s;
          bestScore = score;
        }
      }
      suit = Suit.values[bestSuit];
    } else if (settings.memory == BotMemory.none) {
      suit = Suit.values.reduce(
        (a, b) => _suitScore(view.hand, b) > _suitScore(view.hand, a) ? b : a,
      );
    } else {
      suit = _bestEstimateSuit(view.hand);
    }
    return ChooseTrump(view.seat, suit);
  }

  /// Beginner: the longest suit, then the one with most points.
  static int _suitScore(List<Card> hand, Suit suit) {
    final cards = hand.where((card) => card.suit == suit);
    return cards.length * 16 +
        cards.map(TwentyNineRules.points).fold(0, (a, b) => a + b);
  }

  // Doubling.

  TwentyNineAction _double(TwentyNineView view, BotContext context) {
    final contract = view.contract!;
    final bool doubles;
    if (_searches && context.budget > 0) {
      doubles = _chanceOfMaking(view, context) < 0.3;
    } else if (settings.memory == BotMemory.none) {
      doubles = false;
    } else {
      final hand = view.hand;
      final strength =
          hand.map(TwentyNineRules.points).fold(0, (a, b) => a + b) +
          2 * hand.where((card) => card.rank == Rank.jack).length;
      doubles = contract >= 20 && strength >= 8;
    }
    return doubles ? Double(view.seat) : NoDouble(view.seat);
  }

  TwentyNineAction _redouble(TwentyNineView view, BotContext context) {
    final bool redoubles;
    if (_searches && context.budget > 0) {
      redoubles = _chanceOfMaking(view, context) > 0.75;
    } else if (settings.memory == BotMemory.none) {
      redoubles = false;
    } else {
      final trump = view.trumpSuit;
      redoubles =
          view.bidder == view.seat &&
          trump != null &&
          _estimate(view.hand, trump) >= view.contract! + 3;
    }
    return redoubles ? Redouble(view.seat) : NoRedouble(view.seat);
  }

  /// The share of sampled deals in which the bidding team makes its
  /// contract. Trump is the bidder's choice when the bot knows it, else the
  /// bidder's longest suit in each sample.
  double _chanceOfMaking(TwentyNineView view, BotContext context) {
    final deals = _sampleDeals(view, context);
    final bidder = view.bidder!.index;
    final known = view.trumpSuit?.index;
    final random = context.random;
    final points = _playouts(
      view,
      deals,
      bidder,
      (hands) => known ?? longestSuit(hands[bidder], random),
    );
    return points.where((p) => p >= view.contract!).length / points.length;
  }

  // Single hand.

  TwentyNineAction _singleHand(TwentyNineView view) =>
      settings.inference && _unbeatable(view.hand)
      ? DeclareSingleHand(view.seat)
      : NoSingleHand(view.seat);

  /// Whether every card in [hand] is among the top cards of its suit, so
  /// leading them one by one wins every trick.
  static bool _unbeatable(List<Card> hand) {
    final mask = C29.maskOf(hand);
    for (var suit = 0; suit < 4; suit++) {
      final held = C29.count(mask & C29.suitMask(suit));
      for (var i = 0; i < held; i++) {
        if (!C29.has(mask, suit * 8 + C29.slotsByPower[i])) return false;
      }
    }
    return true;
  }

  // Play.

  TwentyNineAction _play(TwentyNineView view, BotContext context) {
    final legal = view.legalActions;
    if (settings.mistakePercent > 0 &&
        context.random.nextBounded(100) < settings.mistakePercent) {
      return legal[context.random.nextBounded(legal.length)];
    }
    if (_searches && context.budget > 0) {
      return switch (settings.search) {
        BotSearch.pimc => _pimc(view, context),
        BotSearch.ismcts => _ismcts(view, context),
        _ => _lookahead(view, context),
      };
    }
    if (settings.memory == BotMemory.none) return _basicPlay(view);
    return _heuristicPlay(view);
  }

  /// The most cards left to play for the exact endgame: from trick 5, when
  /// each deal solves in well under a millisecond, so that even 2,000 of
  /// them stay within the time a move may take on a phone.
  static const int _exactCards = 12;

  /// Every possible deal, if few enough remain (AGENTS.md §8.3.6).
  List<WeightedWorld>? _exactWorlds(TwentyNineView view, Beliefs beliefs) =>
      settings.exactLimit > 0 && _cardsLeft(view) <= _exactCards
      ? beliefs.enumerate(settings.exactLimit)
      : null;

  /// Expert: Perfect Information Monte Carlo (AGENTS.md §8.3.4). Each
  /// sampled deal, or every possible one near the end, is solved with
  /// alpha-beta; the action with the best average wins.
  TwentyNineAction _pimc(TwentyNineView view, BotContext context) {
    final k = Knowledge.of(view, inference: settings.inference);
    final beliefs = Beliefs(view, k, soft: settings.beliefs);
    final worlds =
        _exactWorlds(view, beliefs) ??
        beliefs.sample(context.random, context.budget);
    if (worlds.isEmpty) return _heuristicPlay(view);
    return _solveWorlds(view, worlds);
  }

  /// Master: Information Set Monte Carlo Tree Search over deals weighted by
  /// the auction (AGENTS.md §8.3.5); every possible deal solved near the
  /// end.
  TwentyNineAction _ismcts(TwentyNineView view, BotContext context) {
    final k = Knowledge.of(view, inference: settings.inference);
    final beliefs = Beliefs(view, k, soft: settings.beliefs);
    final exact = _exactWorlds(view, beliefs);
    if (exact != null) return _solveWorlds(view, exact);
    if (settings.solveCards > 0 && _cardsLeft(view) <= settings.solveCards) {
      final worlds = beliefs.sample(context.random, settings.solveSamples);
      if (worlds.isNotEmpty) return _solveWorlds(view, worlds);
    }
    final pool = beliefs.sample(context.random, math.min(context.budget, 400));
    if (pool.isEmpty) return _heuristicPlay(view);
    final move = Ismcts(view, k, [
      for (final (:world, weight: _) in pool) world,
    ], context.random).search(context.budget);
    return actionOf(view, move);
  }

  /// The cards still to be played in the deal [view] shows.
  static int _cardsLeft(TwentyNineView view) {
    var left = view.hand.length;
    for (final (seat, size) in view.handSizes.indexed) {
      if (seat != view.seat.index) left += size;
    }
    return left + (view.seventhCardSetAside ? 1 : 0);
  }

  /// The legal action whose outcome over [worlds] is best for the bot's
  /// side, each deal solved with alpha-beta and counted by its weight:
  /// contracts made or defeated first, card points to break ties
  /// (AGENTS.md §8.3.7). Asking for trump is worth the best card it allows.
  TwentyNineAction _solveWorlds(
    TwentyNineView view,
    List<WeightedWorld> worlds,
  ) {
    final me = view.seat.index;
    final outcomes = <int, double>{};
    final points = <int, double>{};
    for (final (:world, :weight) in worlds) {
      final rules = DealRules.of(view, world.trump);
      final sign = (me & 1) == rules.side ? 1 : -1;
      final solved = Solver(rules).solve(DealPosition.of(view, world));
      var askOutcome = -2;
      var askPoints = 0;
      for (final (move, value) in solved) {
        final outcome = sign * DealValue.outcome(value);
        final cardPoints = sign * DealValue.points(value);
        if (move & askFlag != 0) {
          if (outcome > askOutcome ||
              (outcome == askOutcome && cardPoints > askPoints)) {
            askOutcome = outcome;
            askPoints = cardPoints;
          }
        } else {
          outcomes[move] = (outcomes[move] ?? 0) + weight * outcome;
          points[move] = (points[move] ?? 0) + weight * cardPoints;
        }
      }
      if (askOutcome > -2) {
        outcomes[askMove] = (outcomes[askMove] ?? 0) + weight * askOutcome;
        points[askMove] = (points[askMove] ?? 0) + weight * askPoints;
      }
    }
    TwentyNineAction? best;
    var bestOutcome = double.negativeInfinity;
    var bestPoints = double.negativeInfinity;
    for (final action in view.legalActions) {
      final move = switch (action) {
        PlayCard(:final card) => C29.index(card),
        AskTrump() => askMove,
        _ => throw StateError('$action is not a play'),
      };
      final outcome = outcomes[move];
      if (outcome == null) continue;
      final cardPoints = points[move]!;
      if (outcome > bestOutcome + 1e-9 ||
          (outcome > bestOutcome - 1e-9 && cardPoints > bestPoints + 1e-9)) {
        best = action;
        bestOutcome = outcome;
        bestPoints = cardPoints;
      }
    }
    return best ?? _heuristicPlay(view);
  }

  static int _playable(TwentyNineView view) {
    var mask = 0;
    for (final action in view.legalActions) {
      if (action is PlayCard) mask |= 1 << C29.index(action.card);
    }
    return mask;
  }

  static TwentyNineAction _playCard(TwentyNineView view, int card) =>
      PlayCard(view.seat, C29.card(card));

  /// The strength of the card at [position] on the current trick, as the
  /// engine judges it: a trump-suit card is a trump only if played once
  /// trump was revealed, or if trump itself was led (AGENTS.md §6.9).
  static int _strength(TwentyNineView view, int position) {
    final card = view.trick[position].card;
    final led = view.trick.first.card.suit;
    final from = trumpCountsFrom(view);
    if (card.suit == view.trumpSuit &&
        from != Sim.noTrump &&
        (position >= from || led == view.trumpSuit)) {
      return 100 + TwentyNineRules.power(card.rank);
    }
    if (card.suit == led) return TwentyNineRules.power(card.rank);
    return -1;
  }

  /// The position of the play winning the current trick so far.
  static int _winningPosition(TwentyNineView view) {
    var best = 0;
    for (var i = 1; i < view.trick.length; i++) {
      if (_strength(view, i) > _strength(view, best)) best = i;
    }
    return best;
  }

  static TrickPlay _winningPlay(TwentyNineView view) =>
      view.trick[_winningPosition(view)];

  /// Beginner: lead the strongest card; follow high only to beat the trick;
  /// otherwise throw the cheapest card, asking for trump only when a trick
  /// holds at least a Jack's worth of points.
  TwentyNineAction _basicPlay(TwentyNineView view) {
    final playable = _playable(view);
    if (playable == 0) return AskTrump(view.seat);
    if (view.trick.isEmpty) {
      var best = -1;
      for (final card in C29.list(playable)) {
        if (best < 0 ||
            C29.power(card) > C29.power(best) ||
            (C29.power(card) == C29.power(best) &&
                C29.points(card) > C29.points(best))) {
          best = card;
        }
      }
      return _playCard(view, best);
    }
    final led = view.trick.first.card.suit.index;
    final following = playable & C29.suitMask(led);
    if (following != 0) {
      var bestLed = -1;
      for (final play in view.trick) {
        final card = C29.index(play.card);
        if (C29.suitOf(card) == led &&
            (bestLed < 0 || C29.power(card) > C29.power(bestLed))) {
          bestLed = card;
        }
      }
      final top = C29.strongest(following, led);
      return _playCard(
        view,
        C29.power(top) > C29.power(bestLed) ? top : C29.weakest(following, led),
      );
    }
    final ask = AskTrump(view.seat);
    final trickPoints = view.trick
        .map((play) => TwentyNineRules.points(play.card))
        .fold(0, (a, b) => a + b);
    if (trickPoints >= 3 && view.legalActions.contains(ask)) return ask;
    return _playCard(view, C29.cheapest(playable));
  }

  /// Casual: heuristics that look only at the current trick and the trump.
  TwentyNineAction _heuristicPlay(TwentyNineView view) {
    final playable = _playable(view);
    final canAsk = view.legalActions.contains(AskTrump(view.seat));
    if (playable == 0) return AskTrump(view.seat);
    final me = view.seat;
    final trump = view.trumpSuit?.index ?? -1;
    final trumpActive = view.trumpRevealed && view.singleHandDeclarer == null;

    if (view.trick.isEmpty) {
      final biddingSide =
          view.bidder != null &&
          TwentyNineRules.teamOf(view.bidder!) == TwentyNineRules.teamOf(me);
      if (trumpActive && biddingSide && trump >= 0) {
        final top = C29.strongest(playable, trump);
        if (top >= 0 && C29.power(top) >= 6) return _playCard(view, top);
      }
      // Lead a Jack of a plain suit: nobody can beat it in its suit.
      var jack = -1;
      for (var suit = 0; suit < 4; suit++) {
        if (suit == trump) continue;
        final card = suit * 8 + 4;
        if (C29.has(playable, card)) jack = card;
      }
      if (jack >= 0) return _playCard(view, jack);
      var longest = -1;
      var length = 0;
      for (var suit = 0; suit < 4; suit++) {
        if (suit == trump) continue;
        final count = C29.count(playable & C29.suitMask(suit));
        if (count > length) {
          longest = suit;
          length = count;
        }
      }
      final pool = longest >= 0 ? playable & C29.suitMask(longest) : playable;
      return _playCard(view, C29.cheapest(pool));
    }

    final winning = _winningPlay(view);
    final partnerWinning =
        TwentyNineRules.teamOf(winning.seat) == TwentyNineRules.teamOf(me);
    final trickSize = view.singleHandDeclarer == null ? 4 : 3;
    final last = view.trick.length == trickSize - 1;
    final trickPoints = view.trick
        .map((play) => TwentyNineRules.points(play.card))
        .fold(0, (a, b) => a + b);
    final winningCard = C29.index(winning.card);
    final led = view.trick.first.card.suit.index;
    final following = playable & C29.suitMask(led);

    if (following != 0 && view.mustTrump != me) {
      if (partnerWinning) {
        final safe = last || C29.power(winningCard) == 7;
        return _playCard(
          view,
          safe ? C29.richest(following) : C29.cheapest(following),
        );
      }
      if (C29.suitOf(winningCard) == led) {
        var beaters = 0;
        for (final card in C29.list(following)) {
          if (C29.power(card) > C29.power(winningCard)) beaters |= 1 << card;
        }
        if (beaters != 0) {
          final top = C29.strongest(beaters, led);
          if (last) return _playCard(view, C29.weakest(beaters, led));
          if (C29.power(top) == 7) return _playCard(view, top);
          if (trickPoints >= 2) {
            return _playCard(view, C29.weakest(beaters, led));
          }
        }
      }
      return _playCard(view, C29.cheapest(following));
    }

    // Cannot follow suit.
    if (canAsk) {
      final worthIt =
          !partnerWinning && (trickPoints >= 2 || C29.power(winningCard) >= 6);
      final holdsTrump =
          view.bidder != me ||
          (trump >= 0 && playable & C29.suitMask(trump) != 0);
      if (worthIt && holdsTrump) return AskTrump(me);
      return _playCard(
        view,
        partnerWinning ? C29.richest(playable) : C29.cheapest(playable),
      );
    }
    final trumps = trumpActive && trump >= 0
        ? playable & C29.suitMask(trump)
        : 0;
    if (!partnerWinning && trumps != 0) {
      var winners = trumps;
      if (_strength(view, _winningPosition(view)) >= 100) {
        winners = 0;
        for (final card in C29.list(trumps)) {
          if (C29.power(card) > C29.power(winningCard)) winners |= 1 << card;
        }
      }
      if (winners != 0 && (trickPoints >= 1 || view.mustTrump == me)) {
        return _playCard(view, C29.weakest(winners, trump));
      }
    }
    final plain = trumps != 0 ? playable & ~C29.suitMask(trump) : playable;
    final pool = plain != 0 ? plain : playable;
    return _playCard(
      view,
      partnerWinning ? C29.richest(pool) : C29.cheapest(pool),
    );
  }

  /// Skilled: looks one move ahead. In each sampled deal it tries every
  /// legal action, then plays the rest of the deal out quickly with
  /// [Greedy] play for all four seats. It keeps the action that most often
  /// meets its side's goal: making the contract as bidders, defeating it as
  /// defenders (AGENTS.md §8.3). Card points break ties.
  TwentyNineAction _lookahead(TwentyNineView view, BotContext context) {
    final k = Knowledge.of(view, inference: settings.inference);
    final worlds = <World>[];
    for (var i = 0; i < context.budget; i++) {
      final world = sampleWorld(k, context.random);
      if (world != null) worlds.add(world);
    }
    if (worlds.isEmpty) return _heuristicPlay(view);

    TwentyNineAction? best;
    var bestValue = double.negativeInfinity;
    for (final action in view.legalActions) {
      var total = 0.0;
      for (final world in worlds) {
        total += _playoutValue(view, k, world, action);
      }
      if (total > bestValue + 1e-9) {
        best = action;
        bestValue = total;
      }
    }
    return best!;
  }

  /// How [action] works out in [world] once the rest of the deal is played
  /// out: 10 when the bot's side meets its goal, -10 when it fails, 0 when
  /// the deal is void, plus a little per card point of lead.
  double _playoutValue(
    TwentyNineView view,
    Knowledge k,
    World world,
    TwentyNineAction action,
  ) {
    final sim = simulate(view, k, world);
    final me = view.seat.index;
    final ours = Sim.team(me);
    switch (action) {
      case PlayCard(:final card):
        sim.play(me, C29.index(card));
      case AskTrump():
        sim
          ..ask(me)
          ..play(me, Greedy.choose(sim, me));
      default:
        throw StateError('$action is not a play');
    }
    sim.playOut();
    final declarer = view.singleHandDeclarer;
    if (declarer != null) {
      final team = Sim.team(declarer.index);
      final declarerWon = sim.tricksWon[1 - team] == 0;
      return (team == ours) == declarerWon ? 10 : -10;
    }
    final bidding = Sim.team(view.bidder!.index);
    final outcome = !sim.revealed
        ? 0
        : sim.points[bidding] >= view.target!
        ? 1
        : -1;
    final forUs = ours == bidding ? outcome : -outcome;
    return forUs * 10.0 + (sim.points[ours] - sim.points[1 - ours]) * 0.05;
  }
}
