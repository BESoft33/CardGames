import 'package:game_core/game_core.dart';

import 'actions.dart';

/// Why a deal was cancelled and the same dealer shuffled again.
enum DealCancelReason {
  /// Redeal check A: the first player's four cards hold no point card.
  firstPlayerNoPointCards,

  /// Redeal check B: a player's eight cards hold no point card.
  playerNoPointCards,

  /// Redeal check B: one player holds all four Jacks.
  allFourJacks,

  /// Redeal check B: one player holds eight cards of one suit.
  eightOfOneSuit,

  /// All four players passed, with the redeal option for that case.
  allPassed,
}

/// How a deal ended.
enum DealOutcome {
  /// The bidder's team reached its target.
  contractMade,

  /// The bidder's team fell short of its target.
  contractFailed,

  /// Trump was never revealed, so nobody scores.
  voided,

  /// The single-hand declarer won all eight tricks.
  singleHandWon,

  /// The single-hand declarer lost a trick.
  singleHandLost,
}

/// Something that happened in a match of Twenty-Nine. Its [type] is
/// `twentynine.` followed by [name], for example `twentynine.cardPlayed`.
sealed class TwentyNineEvent implements GameEvent {
  const TwentyNineEvent();

  /// The event's name without the game prefix.
  String get name;

  @override
  String get type => 'twentynine.$name';

  @override
  Seat? get actor => null;

  /// The event as JSON: type, actor and payload.
  Map<String, Object?> toJson() => {
    'type': type,
    'actor': actor?.id,
    'payload': payload,
  };

  @override
  String toString() => '$type ${actor?.id ?? '-'} $payload';
}

/// A player's action, recorded as it was taken.
final class ActionTaken extends TwentyNineEvent {
  /// Records [action].
  const ActionTaken(this.action);

  /// The action taken.
  final TwentyNineAction action;

  @override
  String get name => action.eventName;

  @override
  Seat get actor => action.seat;

  @override
  Map<String, Object?> get payload => action.data;
}

/// The cards were shuffled and the first four dealt to each player.
final class DealStarted extends TwentyNineEvent {
  /// Records the start of deal [dealNumber].
  const DealStarted({
    required this.dealNumber,
    required this.dealer,
    this.seed,
    this.deck,
  });

  /// The deal's number in the match, from 1. A redeal keeps the number.
  final int dealNumber;

  /// The dealer.
  final Seat dealer;

  /// The shuffle seed, or null when the deal used a given deck order.
  final int? seed;

  /// The given deck order, or null when the deal was shuffled from [seed].
  final List<Card>? deck;

  @override
  String get name => 'dealStarted';

  @override
  Map<String, Object?> get payload => {
    'dealNumber': dealNumber,
    'dealer': dealer.index,
    if (seed case final seed?) 'seed': seedToHex(seed),
    if (deck case final deck?) 'deck': [for (final card in deck) card.id],
  };
}

/// The deal was cancelled with no score; the same dealer shuffles again.
final class DealCancelled extends TwentyNineEvent {
  /// Records the cancellation for [reason].
  const DealCancelled(this.reason);

  /// Why the deal was cancelled.
  final DealCancelReason reason;

  @override
  String get name => 'dealCancelled';

  @override
  Map<String, Object?> get payload => {'reason': reason.name};
}

/// The auction ended: [bidder] plays to make [contract] points.
final class AuctionWon extends TwentyNineEvent {
  /// Records the end of the auction.
  const AuctionWon(this.bidder, this.contract);

  /// The player who won the auction.
  final Seat bidder;

  /// The winning bid.
  final int contract;

  @override
  String get name => 'auctionWon';

  @override
  Map<String, Object?> get payload => {
    'bidder': bidder.index,
    'contract': contract,
  };
}

/// The hidden trump was shown to everyone.
final class TrumpRevealed extends TwentyNineEvent {
  /// Records the reveal of [suit], caused by [revealedBy].
  const TrumpRevealed(this.revealedBy, this.suit, {this.seventhCard});

  /// The player who asked for trump, or who played the seventh card.
  final Seat revealedBy;

  /// The trump suit.
  final Suit suit;

  /// The seventh card, when trump was chosen that way.
  final Card? seventhCard;

  @override
  String get name => 'trumpRevealed';

  @override
  Seat get actor => revealedBy;

  @override
  Map<String, Object?> get payload => {
    'suit': suit.letter,
    if (seventhCard case final card?) 'seventhCard': card.id,
  };
}

/// A Pair declaration changed the bidding team's target.
final class TargetChanged extends TwentyNineEvent {
  /// Records the new [target].
  const TargetChanged(this.target);

  /// The points the bidding team now needs.
  final int target;

  @override
  String get name => 'targetChanged';

  @override
  Map<String, Object?> get payload => {'target': target};
}

/// [winner] won trick number [trickNumber], worth [points] card points.
final class TrickWon extends TwentyNineEvent {
  /// Records the trick.
  const TrickWon(this.winner, this.trickNumber, this.points);

  /// The player who won the trick.
  final Seat winner;

  /// The trick's number in the deal, from 1 to 8.
  final int trickNumber;

  /// The card points in the trick, without the last-trick point.
  final int points;

  @override
  String get name => 'trickWon';

  @override
  Map<String, Object?> get payload => {
    'winner': winner.index,
    'trick': trickNumber,
    'points': points,
  };
}

/// The deal was scored.
final class DealScored extends TwentyNineEvent {
  /// Records the result of the deal.
  const DealScored({
    required this.outcome,
    required this.team,
    required this.delta,
    required this.stake,
    required this.teamPoints,
    required this.scores,
    this.target,
  });

  /// How the deal ended.
  final DealOutcome outcome;

  /// The team whose score could change: the bidding team, or the single-hand
  /// declarer's team.
  final int team;

  /// The change to [team]'s game points; 0 for a voided deal.
  final int delta;

  /// The stake: 1, 2 doubled, 4 redoubled, 3 for single hand.
  final int stake;

  /// The bidding team's target, or null for single hand.
  final int? target;

  /// Card points won by each team, including the last-trick point.
  final List<int> teamPoints;

  /// Each team's game points after the deal.
  final List<int> scores;

  /// The team that won the deal: [team] if it made its contract or its
  /// single hand, the other team if it fell short, and null for a voided
  /// deal, which nobody wins.
  int? get winningTeam => switch (outcome) {
    DealOutcome.contractMade || DealOutcome.singleHandWon => team,
    DealOutcome.contractFailed || DealOutcome.singleHandLost => 1 - team,
    DealOutcome.voided => null,
  };

  @override
  String get name => 'dealScored';

  @override
  Map<String, Object?> get payload => {
    'outcome': outcome.name,
    'team': team,
    'delta': delta,
    'stake': stake,
    'target': ?target,
    'teamPoints': teamPoints,
    'scores': scores,
  };
}

/// The match is over.
final class MatchEnded extends TwentyNineEvent {
  /// Records the end of the match.
  const MatchEnded(this.winningTeam, this.scores);

  /// The team that won: 0 for seats 0 and 2, 1 for seats 1 and 3.
  final int winningTeam;

  /// Each team's final game points.
  final List<int> scores;

  @override
  String get name => 'matchEnded';

  @override
  Map<String, Object?> get payload => {
    'winningTeam': winningTeam,
    'scores': scores,
  };
}
