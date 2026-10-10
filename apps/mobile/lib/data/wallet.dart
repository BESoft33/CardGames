import 'package:sync_protocol/sync_protocol.dart';

import 'event_log.dart';
import 'local_database.dart';

/// The player's coins as this device knows them (AGENTS.md §11).
///
/// The server owns the balance. The device shows what the server last
/// confirmed and, apart from it, what was recorded here and waits for the
/// server: the new-player gift and each staked match's fee and rewards.
final class Wallet {
  /// Creates a wallet.
  const Wallet({
    this.confirmed,
    this.pending = const [],
    this.history = const [],
  });

  /// The balance the server last confirmed, or null before the first sync.
  final int? confirmed;

  /// What waits for the server, newest first.
  final List<PendingCoins> pending;

  /// Matches the server has settled, newest first (AGENTS.md §9).
  final List<MatchSummary> history;

  /// The sum of everything pending; negative if fees outweigh rewards.
  int get pendingTotal => pending.fold(0, (sum, item) => sum + item.amount);

  /// What the player may spend now: the confirmed balance plus everything
  /// pending. The server checks every fee again when it replays the matches.
  int get spendable => (confirmed ?? 0) + pendingTotal;

  /// Whether the player can pay a table fee of [stake].
  bool canPay(int stake) => spendable >= stake;
}

/// Coins recorded on this device that the server has not confirmed yet.
sealed class PendingCoins {
  const PendingCoins();

  /// Coins in when positive, out when negative.
  int get amount;
}

/// The gift every new player gets ([Economy.welcomeGift]).
final class PendingGift extends PendingCoins {
  /// The gift.
  const PendingGift();

  @override
  int get amount => Economy.welcomeGift;
}

/// A staked match: its fee and the rewards it has earned so far.
final class PendingMatch extends PendingCoins {
  /// Creates the record of a match.
  PendingMatch({
    required this.matchId,
    required this.gameId,
    required this.status,
    required this.startedAt,
    required this.entries,
  }) : assert(
         entries.isNotEmpty && entries.first.reason == CoinReason.entryFee,
         'a staked match starts with its fee',
       );

  /// The match.
  final String matchId;

  /// Its game.
  final String gameId;

  /// Whether it is being played, finished or abandoned.
  final MatchStatus status;

  /// When it was created.
  final DateTime startedAt;

  /// The coins it moved, the fee first.
  final List<CoinEntry> entries;

  /// The table fee.
  int get stake => -entries.first.amount;

  /// How many deals the player's team won.
  int get dealsWon =>
      entries.where((entry) => entry.reason == CoinReason.dealWon).length;

  /// Whether the player's side won the match.
  bool get won => entries.any((entry) => entry.reason == CoinReason.matchWon);

  @override
  int get amount => entries.fold(0, (sum, entry) => sum + entry.amount);
}

/// Reads the player's wallet (AGENTS.md §5.8).
abstract interface class WalletRepository {
  /// The wallet as it stands now.
  Future<Wallet> load();
}

/// The wallet as this device knows it: the balance the server last
/// confirmed, and pending coins worked out from the event log.
///
/// Matches the server has settled are deleted from the log, so they are in
/// the confirmed balance and not pending. The starting gift is pending
/// until the server has confirmed a balance once. Amounts come from the
/// shared coin rules, never from the log (AGENTS.md §11).
final class LocalWalletRepository implements WalletRepository {
  /// A wallet read from [_log], with the confirmed balance from
  /// [confirmed], which gives null before the first sync.
  LocalWalletRepository(this._log, {Future<int?> Function()? confirmed})
    : _confirmed = confirmed ?? (() async => null);

  final EventLog _log;
  final Future<int?> Function() _confirmed;

  @override
  Future<Wallet> load() async {
    final matches = <PendingMatch>[];
    for (final match in await _log.coinMatches()) {
      final List<CoinEntry> entries;
      try {
        entries = matchCoins(match.events);
      } on FormatException {
        // A broken record earns nothing here; the server would reject it.
        continue;
      }
      if (entries.isEmpty || entries.first.reason != CoinReason.entryFee) {
        continue;
      }
      matches.add(
        PendingMatch(
          matchId: match.matchId,
          gameId: match.gameId,
          status: match.status,
          startedAt: match.startedAt,
          entries: entries,
        ),
      );
    }
    final confirmed = await _confirmed();
    return Wallet(
      confirmed: confirmed,
      pending: [
        ...matches.reversed,
        if (confirmed == null) const PendingGift(),
      ],
      history: await _log.summaries(),
    );
  }
}

/// A wallet with set contents, for tests.
final class FakeWalletRepository implements WalletRepository {
  /// A repository that returns [wallet].
  FakeWalletRepository([this.wallet = const Wallet()]);

  /// What [load] returns.
  Wallet wallet;

  @override
  Future<Wallet> load() async => wallet;
}
