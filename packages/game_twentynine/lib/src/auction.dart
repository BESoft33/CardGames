import 'package:game_core/game_core.dart';

import 'rules.dart';
import 'state.dart';

/// Where an auction stands (AGENTS.md §6.4), worked out from its calls.
///
/// Bidding goes round in the order of the deal, from the first player, but
/// only two players bid at a time: the old bidder, in the auction longer,
/// and the new one. The old bidder may match the new one's bid; the new one
/// must raise or pass. When one of them passes, the next player joins
/// against the one left, who is now the old bidder.
final class AuctionPosition {
  const AuctionPosition._({
    required this.old,
    required this.newer,
    required this.turn,
    required this.high,
    required this.holder,
    required this.allPassed,
  });

  /// Plays [calls] through from the start of an auction that
  /// [firstPlayer] opens, with bids up to [maxBid].
  ///
  /// Throws a [StateError] if a call is out of turn.
  factory AuctionPosition.of(
    List<AuctionCall> calls,
    Seat firstPlayer,
    int maxBid,
  ) {
    final order = [
      for (var i = 0; i < TwentyNineRules.seatCount; i++)
        firstPlayer.offset(i, TwentyNineRules.seatCount),
    ];
    Seat? old = order[0];
    Seat? newer = order[1];
    var joined = 2;
    Seat? turn = old;
    int? high;
    Seat? holder;
    for (final call in calls) {
      if (call.seat != turn) {
        throw StateError('${call.seat.id} called out of turn');
      }
      final bid = call.bid;
      if (bid != null) {
        high = bid;
        holder = call.seat;
        // A dealer left alone ends the auction by bidding.
        turn = newer == null ? null : (call.seat == old ? newer : old);
      } else {
        final survivor = call.seat == old ? newer : old;
        if (survivor == null) {
          // The dealer, left alone with no bid made, passed as well.
          return const AuctionPosition._(
            old: null,
            newer: null,
            turn: null,
            high: null,
            holder: null,
            allPassed: true,
          );
        }
        old = survivor;
        if (joined < order.length) {
          newer = order[joined++];
          // With a bid made, the newcomer must answer it; with none, the
          // one left opens.
          turn = high == null ? old : newer;
        } else {
          // Nobody is left to join: the one left wins, or, with no bid
          // made, is the dealer, who must call.
          newer = null;
          turn = high == null ? old : null;
        }
      }
      // Nobody can go over the maximum: the auction ends unless the old
      // bidder may still match it.
      if (turn != null && high == maxBid && !(turn == old && holder == newer)) {
        turn = null;
      }
    }
    return AuctionPosition._(
      old: old,
      newer: newer,
      turn: turn,
      high: high,
      holder: holder,
      allPassed: false,
    );
  }

  /// The player in the auction longer, who may match the other's bid.
  final Seat? old;

  /// The player who joined later and must raise or pass; null for a
  /// dealer left alone with no bid made.
  final Seat? newer;

  /// The seat to call, or null once the auction is over.
  final Seat? turn;

  /// The highest bid so far.
  final int? high;

  /// The player holding [high]: the one who bid or matched it last.
  final Seat? holder;

  /// Whether every player passed without a bid.
  final bool allPassed;

  /// Whether the auction is over: won by [holder] with [high], or, if
  /// [allPassed], to be dealt again.
  bool get over => turn == null;

  /// Whether the seat to call may match [high]: it is the old bidder, and
  /// the new one holds the bid.
  bool get mayMatch =>
      turn != null && turn == old && holder != null && holder == newer;

  /// Whether the seat to call is the dealer, left alone with no bid made.
  bool get alone => turn != null && newer == null;
}
