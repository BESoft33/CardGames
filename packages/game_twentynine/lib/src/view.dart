import 'package:game_core/game_core.dart';

import 'actions.dart';
import 'config.dart';
import 'rules.dart';
import 'state.dart';

/// Everything the player in one seat may see of a match of Twenty-Nine, and
/// nothing more (AGENTS.md §8.1).
///
/// It never holds another player's cards, the cards not dealt yet, the seed,
/// or a trump the viewer may not know. Only the bidder sees a hidden trump
/// or their set-aside seventh card.
final class TwentyNineView implements PlayerView {
  /// Creates a view. Use [TwentyNineView.of] or [TwentyNineView.fromJson].
  const TwentyNineView({
    required this.seat,
    required this.config,
    required this.dealNumber,
    required this.dealer,
    required this.scores,
    required this.phase,
    required this.turn,
    required this.legalActions,
    required this.winningTeam,
    required this.hand,
    required this.handSizes,
    required this.calls,
    required this.highBid,
    required this.highBidder,
    required this.bidder,
    required this.contract,
    required this.target,
    required this.trumpMode,
    required this.trumpRevealed,
    required this.trumpSuit,
    required this.seventhCard,
    required this.seventhCardSetAside,
    required this.revealTrick,
    required this.revealedBy,
    required this.doubledBy,
    required this.redoubledBy,
    required this.stake,
    required this.singleHandDeclarer,
    required this.tricks,
    required this.trickLeader,
    required this.trick,
    required this.mustTrump,
    required this.pairBy,
    required this.cardPoints,
  });

  /// What [viewer] may see of [state]. [legalActions] are the viewer's.
  factory TwentyNineView.of(
    TwentyNineState state,
    Seat viewer,
    List<TwentyNineAction> legalActions,
  ) {
    final isBidder = state.bidder == viewer;
    // A pending Pair decision is the holder's alone: everyone else only sees
    // that the game is waiting.
    final hiddenPair =
        state.phase == TwentyNinePhase.pair && state.pairOffer != viewer;
    return TwentyNineView(
      seat: viewer,
      config: state.config,
      dealNumber: state.dealNumber,
      dealer: state.dealer,
      scores: state.scores,
      phase: hiddenPair ? TwentyNinePhase.play : state.phase,
      turn: hiddenPair ? null : state.turn,
      legalActions: List.unmodifiable(legalActions),
      winningTeam: state.winningTeam,
      hand: state.hands[viewer.index],
      handSizes: List.unmodifiable([
        for (final hand in state.hands) hand.length,
      ]),
      calls: state.calls,
      highBid: state.highBid,
      highBidder: state.highBidder,
      bidder: state.bidder,
      contract: state.contract,
      target: state.target,
      trumpMode: state.trumpMode,
      trumpRevealed: state.trumpRevealed,
      trumpSuit: state.trumpRevealed || isBidder ? state.trumpSuit : null,
      seventhCard: state.trumpRevealed || isBidder ? state.seventhCard : null,
      seventhCardSetAside: state.seventhCardSetAside,
      revealTrick: state.revealTrick,
      revealedBy: state.revealedBy,
      doubledBy: state.doubledBy,
      redoubledBy: state.redoubledBy,
      stake: state.stake,
      singleHandDeclarer: state.singleHandDeclarer,
      tricks: state.tricks,
      trickLeader: state.trickLeader,
      trick: state.trick,
      mustTrump: state.mustTrump,
      pairBy: state.pairBy,
      cardPoints: state.cardPoints,
    );
  }

  /// Reads a view written by [toJson].
  factory TwentyNineView.fromJson(Map<String, Object?> json) {
    final trump = json['trump']! as Map<String, Object?>;
    return TwentyNineView(
      seat: Seat(json['seat']! as int),
      config: TwentyNineConfig.fromJson(
        json['config']! as Map<String, Object?>,
      ),
      dealNumber: json['dealNumber']! as int,
      dealer: Seat(json['dealer']! as int),
      scores: _ints(json['scores']),
      phase: TwentyNinePhase.values.byName(json['phase']! as String),
      turn: _seat(json['turn']),
      legalActions: List.unmodifiable([
        for (final action in json['legalActions']! as List<Object?>)
          TwentyNineAction.fromJson(action! as Map<String, Object?>),
      ]),
      winningTeam: json['winningTeam'] as int?,
      hand: _cards(json['hand']),
      handSizes: _ints(json['handSizes']),
      calls: List.unmodifiable([
        for (final call in json['calls']! as List<Object?>)
          AuctionCall.fromJson(call! as Map<String, Object?>),
      ]),
      highBid: json['highBid'] as int?,
      highBidder: _seat(json['highBidder']),
      bidder: _seat(json['bidder']),
      contract: json['contract'] as int?,
      target: json['target'] as int?,
      trumpMode: TrumpMode.values.byName(trump['mode']! as String),
      trumpRevealed: trump['revealed']! as bool,
      trumpSuit: switch (trump['suit']) {
        final String letter => Suit.tryParse(letter),
        _ => null,
      },
      seventhCard: switch (trump['seventhCard']) {
        final String id => Card.parse(id),
        _ => null,
      },
      seventhCardSetAside: trump['seventhCardSetAside']! as bool,
      revealTrick: trump['revealTrick'] as int?,
      revealedBy: _seat(trump['revealedBy']),
      doubledBy: _seat(json['doubledBy']),
      redoubledBy: _seat(json['redoubledBy']),
      stake: json['stake']! as int,
      singleHandDeclarer: _seat(json['singleHandDeclarer']),
      tricks: List.unmodifiable([
        for (final trick in json['tricks']! as List<Object?>)
          Trick.fromJson(trick! as Map<String, Object?>),
      ]),
      trickLeader: _seat(json['trickLeader']),
      trick: List.unmodifiable([
        for (final play in json['trick']! as List<Object?>)
          TrickPlay.fromJson(play! as Map<String, Object?>),
      ]),
      mustTrump: _seat(json['mustTrump']),
      pairBy: _seat(json['pairBy']),
      cardPoints: _ints(json['cardPoints']),
    );
  }

  /// The viewer's seat.
  @override
  final Seat seat;

  /// The rules of the match.
  final TwentyNineConfig config;

  /// The current deal's number, from 1.
  final int dealNumber;

  /// The current dealer.
  final Seat dealer;

  /// Each team's game points; team 0 is seats 0 and 2.
  final List<int> scores;

  /// The current stage.
  final TwentyNinePhase phase;

  /// The seat whose decision is awaited, or null when the viewer may not
  /// know (a pending Pair decision) or the match is over.
  final Seat? turn;

  /// What the viewer may do now; empty when it is not their turn.
  final List<TwentyNineAction> legalActions;

  /// The winning team once the match is over.
  final int? winningTeam;

  /// The viewer's cards, in the order dealt.
  final List<Card> hand;

  /// How many cards each seat holds. A set-aside seventh card is not
  /// counted.
  final List<int> handSizes;

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

  /// The points the bidding team needs.
  final int? target;

  /// How trump was chosen. Calling "seventh card" is public.
  final TrumpMode trumpMode;

  /// Whether trump has been shown to everyone.
  final bool trumpRevealed;

  /// The trump suit, if revealed or the viewer is the bidder.
  final Suit? trumpSuit;

  /// The seventh card, if revealed or the viewer is the bidder.
  final Card? seventhCard;

  /// Whether a seventh card lies face down on the table.
  final bool seventhCardSetAside;

  /// The index of the trick in which trump was revealed.
  final int? revealTrick;

  /// The player who revealed trump: by asking, or by playing the seventh
  /// card. Everyone sees this.
  final Seat? revealedBy;

  /// The opponent who doubled.
  final Seat? doubledBy;

  /// The player who redoubled.
  final Seat? redoubledBy;

  /// The stake: 1, 2 doubled, 4 redoubled, 3 for single hand.
  final int stake;

  /// The player playing single hand.
  final Seat? singleHandDeclarer;

  /// The finished tricks of this deal.
  final List<Trick> tricks;

  /// The player who led, or leads, the current trick.
  final Seat? trickLeader;

  /// The cards played to the current trick.
  final List<TrickPlay> trick;

  /// A player who asked for trump in this trick and must play a trump if
  /// they hold one.
  final Seat? mustTrump;

  /// The player who declared the Pair.
  final Seat? pairBy;

  /// Card points won by each team in this deal so far.
  final List<int> cardPoints;

  /// Whether the game is waiting for the viewer.
  bool get isMyTurn => legalActions.isNotEmpty;

  /// The first player of the deal: next after the dealer.
  Seat get firstPlayer => TwentyNineRules.next(dealer);

  @override
  Map<String, Object?> toJson() => {
    'seat': seat.index,
    'config': config.toJson(),
    'dealNumber': dealNumber,
    'dealer': dealer.index,
    'scores': scores,
    'phase': phase.name,
    'turn': turn?.index,
    'legalActions': [for (final action in legalActions) action.toJson()],
    'winningTeam': winningTeam,
    'hand': [for (final card in hand) card.id],
    'handSizes': handSizes,
    'calls': [for (final call in calls) call.toJson()],
    'highBid': highBid,
    'highBidder': highBidder?.index,
    'bidder': bidder?.index,
    'contract': contract,
    'target': target,
    'trump': {
      'mode': trumpMode.name,
      'revealed': trumpRevealed,
      'suit': trumpSuit?.letter,
      'seventhCard': seventhCard?.id,
      'seventhCardSetAside': seventhCardSetAside,
      'revealTrick': revealTrick,
      'revealedBy': revealedBy?.index,
    },
    'doubledBy': doubledBy?.index,
    'redoubledBy': redoubledBy?.index,
    'stake': stake,
    'singleHandDeclarer': singleHandDeclarer?.index,
    'tricks': [for (final trick in tricks) trick.toJson()],
    'trickLeader': trickLeader?.index,
    'trick': [for (final play in trick) play.toJson()],
    'mustTrump': mustTrump?.index,
    'pairBy': pairBy?.index,
    'cardPoints': cardPoints,
  };

  static Seat? _seat(Object? index) => index is int ? Seat(index) : null;

  static List<int> _ints(Object? list) =>
      List.unmodifiable((list! as List<Object?>).cast<int>());

  static List<Card> _cards(Object? list) => List.unmodifiable([
    for (final id in list! as List<Object?>) Card.parse(id! as String),
  ]);
}
