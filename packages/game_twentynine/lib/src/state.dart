import 'package:game_core/game_core.dart';

import 'config.dart';
import 'events.dart';
import 'rules.dart';

/// The stage a deal is in, and so what kind of decision is awaited.
enum TwentyNinePhase {
  /// Players bid or pass.
  auction,

  /// The bidder names trump or calls "seventh card".
  chooseTrump,

  /// An opponent of the bidder may double.
  doubling,

  /// The bidder, then their partner, may redouble.
  redoubling,

  /// Each player in turn may declare single hand.
  singleHand,

  /// Players play cards to tricks.
  play,

  /// A player may declare the Pair before the next lead.
  pair,

  /// The match is over.
  matchOver,
}

/// How the bidder chose trump.
enum TrumpMode {
  /// Trump has not been chosen yet.
  none,

  /// The bidder named a suit.
  suit,

  /// The bidder called "seventh card".
  seventhCard,
}

/// One call in the auction: a bid, or a pass when [bid] is null.
final class AuctionCall {
  /// Creates a call.
  const AuctionCall(this.seat, this.bid);

  /// The player who called.
  final Seat seat;

  /// The bid, or null for a pass.
  final int? bid;

  /// Reads a call written by [toJson].
  factory AuctionCall.fromJson(Map<String, Object?> json) =>
      AuctionCall(Seat(json['seat']! as int), json['bid'] as int?);

  /// Whether the call was a pass.
  bool get isPass => bid == null;

  /// The call as JSON.
  Map<String, Object?> toJson() => {'seat': seat.index, 'bid': bid};

  @override
  String toString() => '${seat.id} ${bid ?? 'pass'}';
}

/// A card played to a trick.
final class TrickPlay {
  /// Creates a play.
  const TrickPlay(this.seat, this.card);

  /// The player who played the card.
  final Seat seat;

  /// The card played.
  final Card card;

  /// Reads a play written by [toJson].
  factory TrickPlay.fromJson(Map<String, Object?> json) => TrickPlay(
    Seat(json['seat']! as int),
    Card.parse(json['card']! as String),
  );

  /// The play as JSON.
  Map<String, Object?> toJson() => {'seat': seat.index, 'card': card.id};

  @override
  String toString() => '${seat.id} $card';
}

/// A finished trick.
final class Trick {
  /// Creates a finished trick.
  const Trick({
    required this.leader,
    required this.plays,
    required this.winner,
    required this.points,
  });

  /// Reads a trick written by [toJson].
  factory Trick.fromJson(Map<String, Object?> json) => Trick(
    leader: Seat(json['leader']! as int),
    plays: [
      for (final play in json['plays']! as List<Object?>)
        TrickPlay.fromJson(play! as Map<String, Object?>),
    ],
    winner: Seat(json['winner']! as int),
    points: json['points']! as int,
  );

  /// The player who led.
  final Seat leader;

  /// The cards in the order played.
  final List<TrickPlay> plays;

  /// The player who won the trick.
  final Seat winner;

  /// The card points in the trick, without the last-trick point.
  final int points;

  /// The trick as JSON.
  Map<String, Object?> toJson() => {
    'leader': leader.index,
    'plays': [for (final play in plays) play.toJson()],
    'winner': winner.index,
    'points': points,
  };
}

/// The complete state of a match, including hidden information.
///
/// Only the rules engine creates states; players and bots see a
/// [PlayerView] instead.
final class TwentyNineState {
  TwentyNineState._(StateDraft d)
    : config = d.config,
      matchSeed = d.matchSeed,
      seedsUsed = d.seedsUsed,
      dealNumber = d.dealNumber,
      dealer = d.dealer,
      scores = List.unmodifiable(d.scores),
      phase = d.phase,
      turn = d.turn,
      winningTeam = d.winningTeam,
      lastEvents = List.unmodifiable(d.events),
      dealSeed = d.dealSeed,
      hands = List.unmodifiable([
        for (final hand in d.hands) List<Card>.unmodifiable(hand),
      ]),
      undealt = List.unmodifiable(d.undealt),
      calls = List.unmodifiable(d.calls),
      highBid = d.highBid,
      highBidder = d.highBidder,
      bidder = d.bidder,
      contract = d.contract,
      target = d.target,
      trumpMode = d.trumpMode,
      trumpSuit = d.trumpSuit,
      seventhCard = d.seventhCard,
      seventhCardSetAside = d.seventhCardSetAside,
      trumpRevealed = d.trumpRevealed,
      revealTrick = d.revealTrick,
      revealedBy = d.revealedBy,
      doubledBy = d.doubledBy,
      redoubledBy = d.redoubledBy,
      singleHandDeclines = d.singleHandDeclines,
      singleHandDeclarer = d.singleHandDeclarer,
      tricks = List.unmodifiable(d.tricks),
      trickLeader = d.trickLeader,
      trick = List.unmodifiable(d.trick),
      mustTrump = d.mustTrump,
      pairOffer = d.pairOffer,
      pairBy = d.pairBy,
      cardPoints = List.unmodifiable(d.cardPoints);

  // Match.

  /// The rules of this match.
  final TwentyNineConfig config;

  /// The seed the match started from. Never shown to players.
  final int matchSeed;

  /// How many values of the seed stream have been used: one for the first
  /// dealer, then one per shuffle.
  final int seedsUsed;

  /// The current deal's number, from 1. A redeal keeps the number.
  final int dealNumber;

  /// The current dealer.
  final Seat dealer;

  /// Each team's game points: team 0 is seats 0 and 2.
  final List<int> scores;

  /// The current stage.
  final TwentyNinePhase phase;

  /// The seat whose decision is awaited, or null when the match is over.
  final Seat? turn;

  /// The winning team once the match is over.
  final int? winningTeam;

  /// What happened in the engine call that produced this state, in order.
  final List<TwentyNineEvent> lastEvents;

  // Deal.

  /// The current deal's shuffle seed, or null when it used a given deck.
  final int? dealSeed;

  /// Each seat's cards, in the order dealt. The bidder's set-aside seventh
  /// card is not included.
  final List<List<Card>> hands;

  /// The second four cards of each player, not dealt yet, in deal order.
  final List<Card> undealt;

  /// The auction so far.
  final List<AuctionCall> calls;

  /// The highest bid so far.
  final int? highBid;

  /// The player who made [highBid].
  final Seat? highBidder;

  /// The player who won the auction.
  final Seat? bidder;

  /// The winning bid.
  final int? contract;

  /// The points the bidding team needs: the contract, moved by a Pair.
  final int? target;

  /// How trump was chosen.
  final TrumpMode trumpMode;

  /// The trump suit, once chosen or once the seventh card is dealt.
  final Suit? trumpSuit;

  /// The bidder's seventh card, when trump was chosen that way.
  final Card? seventhCard;

  /// Whether [seventhCard] is set aside face down.
  final bool seventhCardSetAside;

  /// Whether trump has been shown to everyone.
  final bool trumpRevealed;

  /// The index of the trick in which trump was revealed.
  final int? revealTrick;

  /// The player who asked for trump, or played the seventh card, and so
  /// revealed it.
  final Seat? revealedBy;

  /// The opponent who doubled.
  final Seat? doubledBy;

  /// The player who redoubled.
  final Seat? redoubledBy;

  /// How many players have declined single hand in this deal.
  final int singleHandDeclines;

  /// The player playing single hand.
  final Seat? singleHandDeclarer;

  /// The finished tricks of this deal.
  final List<Trick> tricks;

  /// The player who led, or leads, the current trick.
  final Seat? trickLeader;

  /// The cards played to the current trick.
  final List<TrickPlay> trick;

  /// A player who asked for trump in this trick and must now play a trump
  /// if they hold one.
  final Seat? mustTrump;

  /// The player offered the chance to declare the Pair.
  final Seat? pairOffer;

  /// The player who declared the Pair.
  final Seat? pairBy;

  /// Card points won by each team in this deal so far.
  final List<int> cardPoints;

  /// The first player: next after the dealer.
  Seat get firstPlayer => TwentyNineRules.next(dealer);

  /// The stake: 3 for single hand, else 4 redoubled, 2 doubled, 1.
  int get stake {
    if (singleHandDeclarer != null) return 3;
    if (redoubledBy != null) return 4;
    if (doubledBy != null) return 2;
    return 1;
  }

  /// Whether the match is over.
  bool get isOver => phase == TwentyNinePhase.matchOver;

  /// Whether [seat] has passed in this deal's auction.
  bool hasPassed(Seat seat) =>
      calls.any((call) => call.seat == seat && call.isPass);

  /// The whole state as JSON, hidden information included. Used for the
  /// replay hash; never show it to a player.
  Map<String, Object?> toJson() => {
    'config': config.toJson(),
    'matchSeed': seedToHex(matchSeed),
    'seedsUsed': seedsUsed,
    'dealNumber': dealNumber,
    'dealer': dealer.index,
    'scores': scores,
    'phase': phase.name,
    'turn': turn?.index,
    'winningTeam': winningTeam,
    'dealSeed': dealSeed == null ? null : seedToHex(dealSeed!),
    'hands': [
      for (final hand in hands) [for (final card in hand) card.id],
    ],
    'undealt': [for (final card in undealt) card.id],
    'calls': [for (final call in calls) call.toJson()],
    'highBid': highBid,
    'highBidder': highBidder?.index,
    'bidder': bidder?.index,
    'contract': contract,
    'target': target,
    'trumpMode': trumpMode.name,
    'trumpSuit': trumpSuit?.letter,
    'seventhCard': seventhCard?.id,
    'seventhCardSetAside': seventhCardSetAside,
    'trumpRevealed': trumpRevealed,
    'revealTrick': revealTrick,
    'revealedBy': revealedBy?.index,
    'doubledBy': doubledBy?.index,
    'redoubledBy': redoubledBy?.index,
    'singleHandDeclines': singleHandDeclines,
    'singleHandDeclarer': singleHandDeclarer?.index,
    'tricks': [for (final trick in tricks) trick.toJson()],
    'trickLeader': trickLeader?.index,
    'trick': [for (final play in trick) play.toJson()],
    'mustTrump': mustTrump?.index,
    'pairOffer': pairOffer?.index,
    'pairBy': pairBy?.index,
    'cardPoints': cardPoints,
  };

  /// SHA-256 of [toJson]. Replaying the same seed and actions gives the same
  /// hash on every device and on the server (AGENTS.md §6.12).
  String get hash => canonicalHash(toJson());
}

/// A mutable copy of a [TwentyNineState] that the engine edits and then
/// freezes with [toState]. Not part of the package's public API.
final class StateDraft {
  /// Starts a new match. [dealer] and the first deal are set by the engine.
  StateDraft.newMatch(this.config, this.matchSeed)
    : seedsUsed = 0,
      dealNumber = 1,
      dealer = const Seat(0),
      scores = [0, 0],
      phase = TwentyNinePhase.auction,
      hands = [[], [], [], []],
      undealt = [],
      calls = [],
      trumpMode = TrumpMode.none,
      seventhCardSetAside = false,
      trumpRevealed = false,
      singleHandDeclines = 0,
      tricks = [],
      trick = [],
      cardPoints = [0, 0];

  /// Copies [s] so it can be edited.
  StateDraft.of(TwentyNineState s)
    : config = s.config,
      matchSeed = s.matchSeed,
      seedsUsed = s.seedsUsed,
      dealNumber = s.dealNumber,
      dealer = s.dealer,
      scores = List.of(s.scores),
      phase = s.phase,
      turn = s.turn,
      winningTeam = s.winningTeam,
      dealSeed = s.dealSeed,
      hands = [for (final hand in s.hands) List.of(hand)],
      undealt = List.of(s.undealt),
      calls = List.of(s.calls),
      highBid = s.highBid,
      highBidder = s.highBidder,
      bidder = s.bidder,
      contract = s.contract,
      target = s.target,
      trumpMode = s.trumpMode,
      trumpSuit = s.trumpSuit,
      seventhCard = s.seventhCard,
      seventhCardSetAside = s.seventhCardSetAside,
      trumpRevealed = s.trumpRevealed,
      revealTrick = s.revealTrick,
      revealedBy = s.revealedBy,
      doubledBy = s.doubledBy,
      redoubledBy = s.redoubledBy,
      singleHandDeclines = s.singleHandDeclines,
      singleHandDeclarer = s.singleHandDeclarer,
      tricks = List.of(s.tricks),
      trickLeader = s.trickLeader,
      trick = List.of(s.trick),
      mustTrump = s.mustTrump,
      pairOffer = s.pairOffer,
      pairBy = s.pairBy,
      cardPoints = List.of(s.cardPoints);

  /// The events produced by this edit.
  final List<TwentyNineEvent> events = [];

  // Match fields; see [TwentyNineState] for their meaning.
  TwentyNineConfig config;
  int matchSeed;
  int seedsUsed;
  int dealNumber;
  Seat dealer;
  List<int> scores;
  TwentyNinePhase phase;
  Seat? turn;
  int? winningTeam;

  // Deal fields.
  int? dealSeed;
  List<List<Card>> hands;
  List<Card> undealt;
  List<AuctionCall> calls;
  int? highBid;
  Seat? highBidder;
  Seat? bidder;
  int? contract;
  int? target;
  TrumpMode trumpMode;
  Suit? trumpSuit;
  Card? seventhCard;
  bool seventhCardSetAside;
  bool trumpRevealed;
  int? revealTrick;
  Seat? revealedBy;
  Seat? doubledBy;
  Seat? redoubledBy;
  int singleHandDeclines;
  Seat? singleHandDeclarer;
  List<Trick> tricks;
  Seat? trickLeader;
  List<TrickPlay> trick;
  Seat? mustTrump;
  Seat? pairOffer;
  Seat? pairBy;
  List<int> cardPoints;

  /// The first player: next after the dealer.
  Seat get firstPlayer => TwentyNineRules.next(dealer);

  /// The stake: 3 for single hand, else 4 redoubled, 2 doubled, 1.
  int get stake {
    if (singleHandDeclarer != null) return 3;
    if (redoubledBy != null) return 4;
    if (doubledBy != null) return 2;
    return 1;
  }

  /// Clears everything that belongs to one deal.
  void resetDeal() {
    dealSeed = null;
    hands = [[], [], [], []];
    undealt = [];
    calls = [];
    highBid = null;
    highBidder = null;
    bidder = null;
    contract = null;
    target = null;
    trumpMode = TrumpMode.none;
    trumpSuit = null;
    seventhCard = null;
    seventhCardSetAside = false;
    trumpRevealed = false;
    revealTrick = null;
    revealedBy = null;
    doubledBy = null;
    redoubledBy = null;
    singleHandDeclines = 0;
    singleHandDeclarer = null;
    tricks = [];
    trickLeader = null;
    trick = [];
    mustTrump = null;
    pairOffer = null;
    pairBy = null;
    cardPoints = [0, 0];
  }

  /// Freezes the draft into a state.
  TwentyNineState toState() => TwentyNineState._(this);
}
