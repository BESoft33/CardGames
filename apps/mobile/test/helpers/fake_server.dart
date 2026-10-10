import 'package:card_games/data/remote/auth_repository.dart';
import 'package:card_games/data/remote/game_server.dart';
import 'package:cardgames_server/cardgames_server.dart';
import 'package:sync_protocol/sync_protocol.dart';

/// The real game server (`server/`) running in memory: its replay, ledger
/// and merge rules, with the accounts of [auth]. The "fake server" of
/// AGENTS.md §14, so sync is tested against the rules it will meet.
final class InProcessServer implements GameServer {
  /// A server knowing the accounts of [auth].
  InProcessServer(this.auth) : store = MemoryStore() {
    service = SyncService(store: store);
  }

  /// The accounts, by token.
  final FakeAuthRepository auth;

  /// The server's records, for tests to inspect.
  final MemoryStore store;

  /// The server's rules.
  late final SyncService service;

  /// Whether the server answers.
  bool online = true;

  /// Uploads to take, and then pretend the answer was lost.
  int dropAnswers = 0;

  /// Uploads to answer before going offline, or null to stay up.
  int? goOfflineAfter;

  /// How many uploads were received.
  int uploads = 0;

  /// The batches received, as (match, first seq, last seq).
  final List<(String, int, int)> received = [];

  AuthUser _user(String token) {
    final account = auth.accounts[token];
    if (account == null) {
      throw const ServerRefused(401, ApiErrors.unauthorized);
    }
    return AuthUser(
      id: account.id,
      isAnonymous: account.isAnonymous,
      googleSubject: account.googleSubject,
    );
  }

  Future<T> _call<T>(Future<T> Function() body) async {
    if (!online) throw const ServerUnavailable('offline');
    try {
      return await body();
    } on ApiException catch (error) {
      throw ServerRefused(error.status, error.code, error.message);
    }
  }

  @override
  Future<SyncAck> upload(UploadBatch batch, String accessToken) =>
      _call(() async {
        final limit = goOfflineAfter;
        if (limit != null && uploads >= limit) {
          online = false;
          throw const ServerUnavailable('went offline');
        }
        uploads++;
        received.add((
          batch.matchId,
          batch.events.first.seq,
          batch.events.last.seq,
        ));
        final ack = await service.upload(_user(accessToken), batch);
        if (dropAnswers > 0) {
          dropAnswers--;
          throw const ServerUnavailable('the answer was lost');
        }
        return ack;
      });

  @override
  Future<WalletState> wallet(String accessToken) =>
      _call(() => service.wallet(_user(accessToken)));

  @override
  Future<MergeResult> merge(String guestAccessToken, String accessToken) =>
      _call(() => service.merge(_user(accessToken), _user(guestAccessToken)));

  /// The balance of the account [userId] on the server.
  int balanceOf(String userId) => store.ledger
      .where((entry) => entry.userId == userId)
      .fold(0, (sum, entry) => sum + entry.delta);
}
