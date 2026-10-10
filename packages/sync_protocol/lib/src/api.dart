import 'coins.dart';
import 'envelope.dart';

/// The game server's HTTP API (docs/decisions.md D-031). Requests and
/// answers are JSON; uploads may be gzip-compressed. Every `/v1` request
/// carries the player's Supabase access token as `Authorization: Bearer`.
abstract final class ServerApi {
  /// Answers 200 while the server is up.
  static const String health = '/health';

  /// Uploads one batch of a match's events: an [UploadBatch], answered with
  /// a [SyncAck].
  static const String sync = '/v1/sync';

  /// The player's confirmed coins: answered with a [WalletState].
  static const String wallet = '/v1/wallet';

  /// Moves a guest's progress into the signed-in account: a [MergeRequest],
  /// answered with a [MergeResult] (AGENTS.md §10).
  static const String merge = '/v1/account/merge';

  /// The most events one upload may carry (AGENTS.md §9).
  static const int maxBatchEvents = 200;
}

/// Error codes the server answers with, beside an HTTP status.
abstract final class ApiErrors {
  /// The access token is missing, expired or not valid.
  static const String unauthorized = 'unauthorized';

  /// The request is malformed.
  static const String badRequest = 'bad_request';

  /// The account was merged into another and takes no more requests.
  static const String mergedAccount = 'merged_account';

  /// The match or profile belongs to another account.
  static const String notYours = 'not_yours';

  /// The request needs an account signed in with Google.
  static const String needsSignIn = 'needs_sign_in';
}

/// Where the server stands on an uploaded match.
enum MatchSyncStatus {
  /// Valid so far; more events are expected.
  open,

  /// Complete and valid. Its coins are in the ledger.
  accepted,

  /// It does not replay. It earns nothing and is flagged.
  rejected,
}

/// Reads a field of [json], or throws a [FormatException].
T _field<T>(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! T) throw FormatException('Field $key is not $T');
  return value;
}

/// Consecutive events of one match, in `seq` order (AGENTS.md §9).
final class UploadBatch {
  /// Creates a batch.
  const UploadBatch({required this.matchId, required this.events});

  /// Reads a batch written by [toJson].
  ///
  /// Throws a [FormatException] if it is malformed.
  factory UploadBatch.fromJson(Map<String, Object?> json) => UploadBatch(
    matchId: _field<String>(json, 'matchId'),
    events: [
      for (final event in _field<List<Object?>>(json, 'events'))
        if (event is Map<String, Object?>)
          EventEnvelope.fromJson(event)
        else
          throw const FormatException('An event is not an object'),
    ],
  );

  /// The match.
  final String matchId;

  /// Its events, consecutive by `seq`.
  final List<EventEnvelope> events;

  /// The batch as JSON.
  Map<String, Object?> toJson() => {
    'matchId': matchId,
    'events': [for (final event in events) event.toJson()],
  };
}

/// Coins the server credited while answering, for the app to announce.
final class CoinCredit {
  /// Creates a credit.
  const CoinCredit(this.reason, this.amount);

  /// Reads a credit written by [toJson].
  factory CoinCredit.fromJson(Map<String, Object?> json) => CoinCredit(
    CoinReason.values.byName(_field<String>(json, 'reason')),
    _field<int>(json, 'amount'),
  );

  /// Why the coins were credited.
  final CoinReason reason;

  /// How many.
  final int amount;

  /// The credit as JSON.
  Map<String, Object?> toJson() => {'reason': reason.name, 'amount': amount};

  @override
  bool operator ==(Object other) =>
      other is CoinCredit && other.reason == reason && other.amount == amount;

  @override
  int get hashCode => Object.hash(reason, amount);

  @override
  String toString() => 'CoinCredit(${reason.name}, $amount)';
}

/// The player's coins as the server holds them.
final class WalletState {
  /// Creates a wallet state.
  const WalletState({required this.balance, this.credited = const []});

  /// Reads a wallet state written by [toJson].
  factory WalletState.fromJson(Map<String, Object?> json) => WalletState(
    balance: _field<int>(json, 'balance'),
    credited: [
      for (final credit in _field<List<Object?>>(json, 'credited'))
        CoinCredit.fromJson(credit! as Map<String, Object?>),
    ],
  );

  /// The confirmed balance: the sum of the player's ledger.
  final int balance;

  /// One-off credits made just now, such as the starting gift or the Google
  /// sign-up bonus.
  final List<CoinCredit> credited;

  /// The wallet state as JSON.
  Map<String, Object?> toJson() => {
    'balance': balance,
    'credited': [for (final credit in credited) credit.toJson()],
  };
}

/// The server's answer to an upload.
final class SyncAck {
  /// Creates an acknowledgement.
  const SyncAck({
    required this.matchId,
    required this.ackedSeq,
    required this.status,
    required this.wallet,
    this.reason,
  });

  /// Reads an acknowledgement written by [toJson].
  factory SyncAck.fromJson(Map<String, Object?> json) => SyncAck(
    matchId: _field<String>(json, 'matchId'),
    ackedSeq: _field<int>(json, 'ackedSeq'),
    status: MatchSyncStatus.values.byName(_field<String>(json, 'status')),
    reason: json['reason'] as String?,
    wallet: WalletState.fromJson(_field<Map<String, Object?>>(json, 'wallet')),
  );

  /// The match.
  final String matchId;

  /// The last `seq` the server holds for the match, or -1 if none. The next
  /// upload starts after it, so a batch that arrived out of order is simply
  /// sent again from here.
  final int ackedSeq;

  /// Where the server stands on the match.
  final MatchSyncStatus status;

  /// Why the match was rejected, if it was.
  final String? reason;

  /// The player's coins after this upload.
  final WalletState wallet;

  /// The acknowledgement as JSON.
  Map<String, Object?> toJson() => {
    'matchId': matchId,
    'ackedSeq': ackedSeq,
    'status': status.name,
    'reason': ?reason,
    'wallet': wallet.toJson(),
  };
}

/// Asks to move a guest account's progress into the signed-in account.
final class MergeRequest {
  /// Creates a request proving ownership of the guest with its token.
  const MergeRequest({required this.guestAccessToken});

  /// Reads a request written by [toJson].
  factory MergeRequest.fromJson(Map<String, Object?> json) =>
      MergeRequest(guestAccessToken: _field<String>(json, 'guestAccessToken'));

  /// A current access token of the guest account.
  final String guestAccessToken;

  /// The request as JSON.
  Map<String, Object?> toJson() => {'guestAccessToken': guestAccessToken};
}

/// The outcome of a merge.
final class MergeResult {
  /// Creates a result.
  const MergeResult({required this.coinsMoved, required this.wallet});

  /// Reads a result written by [toJson].
  factory MergeResult.fromJson(Map<String, Object?> json) => MergeResult(
    coinsMoved: _field<int>(json, 'coinsMoved'),
    wallet: WalletState.fromJson(_field<Map<String, Object?>>(json, 'wallet')),
  );

  /// Coins added to the signed-in account: what the guest won in matches,
  /// never less than zero. The starting gift does not move.
  final int coinsMoved;

  /// The signed-in account's coins after the merge.
  final WalletState wallet;

  /// The result as JSON.
  Map<String, Object?> toJson() => {
    'coinsMoved': coinsMoved,
    'wallet': wallet.toJson(),
  };
}
