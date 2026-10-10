import 'economy.dart';
import 'envelope.dart';

/// Why coins move (AGENTS.md §11). It names the entry in the server's
/// ledger.
enum CoinReason {
  /// The gift every new player gets.
  welcomeGift,

  /// The bonus for a first sign-up with Google.
  googleSignupBonus,

  /// A table's fee, paid on joining a staked match.
  entryFee,

  /// A deal the player's team won.
  dealWon,

  /// The match the player's side won: their share of the pot.
  matchWon,

  /// A share of the match pot a losing player adds at match end.
  lossPenalty,

  /// The share of the pot that quitting against bots returns.
  quitRefund,

  /// Every fee of a tied game, returned.
  tieRefund,

  /// A guest's winnings, moved into the account it signed in to.
  mergedIn,

  /// A guest's balance, closed when it was merged into another account.
  mergedOut,
}

/// What a match at a given stake costs and pays (docs/decisions.md D-024).
/// A stake of 0 is a practice match, which moves no coins.
abstract final class CoinRules {
  /// Whether [stake] is one of the table fees players may choose.
  static bool isStake(int stake) => Economy.stakes.contains(stake);

  /// The coins each player of a team gets for a deal the team won: a share
  /// of their own fee.
  static int dealWon(int stake) => stake * Economy.dealWonPercent ~/ 100;

  /// The pot of a match at [stake] with [humans] people among [seats]:
  /// every seat's fee when all are people, and [Economy.botPotFees] times
  /// the player's fee against bots, who never win or lose coins.
  ///
  /// Throws an [UnsupportedError] for a table mixing people and bots, whose
  /// pot the owner has not decided (AGENTS.md §17).
  static int pot(int stake, {required int seats, required int humans}) {
    if (humans == 1 && seats > 1) return stake * Economy.botPotFees;
    if (humans == seats) return stake * seats;
    throw UnsupportedError('The pot of a mixed table is not decided yet');
  }

  /// Each winner's share of the pot: the winning side takes it all, and its
  /// [winners], the people on it, split it.
  static int matchWon(
    int stake, {
    required int seats,
    required int humans,
    required int winners,
  }) => pot(stake, seats: seats, humans: humans) ~/ winners;

  /// What each losing player adds at match end: a share of the pot.
  static int lossPenalty(
    int stake, {
    required int seats,
    required int humans,
  }) =>
      pot(stake, seats: seats, humans: humans) *
      Economy.lossPenaltyPercent ~/
      100;

  /// The percentage of the pot quitting against bots returns, by the
  /// player's team [score] in the match at that moment.
  static int quitShare(int score) => score < -Economy.quitLevelBand
      ? Economy.quitShareBehind
      : score > Economy.quitLevelBand
      ? Economy.quitShareAhead
      : Economy.quitShareLevel;

  /// What quitting at [score] returns to the player who quits. Against
  /// bots, a share of the pot; against people, nothing, because the pot
  /// goes to everyone still playing.
  static int quitRefund(
    int stake, {
    required int seats,
    required int humans,
    required int score,
  }) {
    final pot = CoinRules.pot(stake, seats: seats, humans: humans);
    return humans == 1 ? pot * quitShare(score) ~/ 100 : 0;
  }

  /// What a tied game of [matches] matches returns: every fee paid in it.
  static int tieRefund(int stake, {required int matches}) => stake * matches;
}

/// The payloads of the economy events. They name what happened, never an
/// amount: the app and the server work amounts out with [CoinRules].
abstract final class EconomyPayloads {
  /// Joining a table with [seats] seats, [humans] of them people, each
  /// paying [stake].
  static Map<String, Object?> entryFee({
    required int stake,
    required int seats,
    required int humans,
  }) => {'stake': stake, 'seats': seats, 'humans': humans};

  /// The user's team won deal number [deal] of the match, counted from 1.
  static Map<String, Object?> dealWon(int deal) => {
    'reason': CoinReason.dealWon.name,
    'deal': deal,
  };

  /// The user's side won the match; its [winners], the people on it, split
  /// the pot.
  static Map<String, Object?> matchWon({required int winners}) => {
    'reason': CoinReason.matchWon.name,
    'winners': winners,
  };

  /// The user's side lost the match, so the user adds to the pot.
  static Map<String, Object?> lossPenalty() => {
    'reason': CoinReason.lossPenalty.name,
  };

  /// The user quit with their team at [score] game points.
  static Map<String, Object?> quitRefund({required int score}) => {
    'reason': CoinReason.quitRefund.name,
    'score': score,
  };

  /// The user's game ended tied after [matches] matches.
  static Map<String, Object?> tieRefund({required int matches}) => {
    'reason': CoinReason.tieRefund.name,
    'matches': matches,
  };
}

/// One movement of coins.
final class CoinEntry {
  /// Records [amount] coins, in or out, for [reason].
  const CoinEntry(this.reason, this.amount, {this.deal});

  /// Why the coins move.
  final CoinReason reason;

  /// Coins in when positive, out when negative.
  final int amount;

  /// The deal won, for [CoinReason.dealWon].
  final int? deal;

  @override
  bool operator ==(Object other) =>
      other is CoinEntry &&
      other.reason == reason &&
      other.amount == amount &&
      other.deal == deal;

  @override
  int get hashCode => Object.hash(reason, amount, deal);

  @override
  String toString() =>
      'CoinEntry(${reason.name}, $amount${deal == null ? '' : ', deal $deal'})';
}

/// The coins that one match's events move for the user who logged them, in
/// order. Events of other kinds are skipped, so a whole match log may be
/// passed.
///
/// Amounts come from [Economy] through [CoinRules], never from the events
/// (AGENTS.md §11). A reward or penalty repeated for the same deal, or the
/// match, counts once. A practice match has no economy events and moves
/// nothing.
///
/// Throws a [FormatException] if a reward or penalty comes before the entry
/// fee, or an event names an unknown stake, table or reward.
List<CoinEntry> matchCoins(Iterable<EventEnvelope> events) {
  final entries = <CoinEntry>[];
  ({int stake, int seats, int humans})? table;
  final dealsWon = <int>{};
  final once = <CoinReason>{};
  ({int stake, int seats, int humans}) paid() =>
      table ??
      (throw const FormatException('A reward came before the entry fee'));
  void add(CoinReason reason, int amount) {
    if (once.add(reason)) entries.add(CoinEntry(reason, amount));
  }

  for (final event in events) {
    final payload = event.payload;
    switch (event.type) {
      case EventTypes.entryFee:
        if (table != null) {
          throw const FormatException('The match has two entry fees');
        }
        if (payload
            case {
              'stake': final int fee,
              'seats': final int seats,
              'humans': final int humans,
            }
            when CoinRules.isStake(fee) &&
                seats >= 2 &&
                (humans == 1 || humans == seats)) {
          table = (stake: fee, seats: seats, humans: humans);
          entries.add(CoinEntry(CoinReason.entryFee, -fee));
        } else {
          throw FormatException('Not a table fee: $payload');
        }
      case EventTypes.penaltyPending:
        final (:stake, :seats, :humans) = paid();
        if (payload case {'reason': 'lossPenalty'}) {
          add(
            CoinReason.lossPenalty,
            -CoinRules.lossPenalty(stake, seats: seats, humans: humans),
          );
        } else {
          throw FormatException('Not a penalty: $payload');
        }
      case EventTypes.rewardPending:
        final (:stake, :seats, :humans) = paid();
        switch (payload) {
          case {'reason': 'dealWon', 'deal': final int deal} when deal >= 1:
            if (dealsWon.add(deal)) {
              entries.add(
                CoinEntry(
                  CoinReason.dealWon,
                  CoinRules.dealWon(stake),
                  deal: deal,
                ),
              );
            }
          case {'reason': 'matchWon', 'winners': final int winners}
              when winners >= 1 && winners <= humans:
            add(
              CoinReason.matchWon,
              CoinRules.matchWon(
                stake,
                seats: seats,
                humans: humans,
                winners: winners,
              ),
            );
          case {'reason': 'quitRefund', 'score': final int score}:
            add(
              CoinReason.quitRefund,
              CoinRules.quitRefund(
                stake,
                seats: seats,
                humans: humans,
                score: score,
              ),
            );
          case {'reason': 'tieRefund', 'matches': final int matches}
              when matches >= 1:
            add(
              CoinReason.tieRefund,
              CoinRules.tieRefund(stake, matches: matches),
            );
          default:
            throw FormatException('Not a reward: $payload');
        }
    }
  }
  return entries;
}
