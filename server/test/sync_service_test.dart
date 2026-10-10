import 'package:cardgames_server/cardgames_server.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const AuthUser guest = AuthUser(id: 'guest-a', isAnonymous: true);
const AuthUser other = AuthUser(id: 'guest-b', isAnonymous: true);
const AuthUser googleUser = AuthUser(
  id: 'user-g',
  isAnonymous: false,
  googleSubject: '1234567890',
);

/// [events] split into batches of at most [size]: smaller than the
/// server's limit of 200, so that a match takes several.
List<UploadBatch> batches(List<EventEnvelope> events, {int size = 50}) => [
  for (var i = 0; i < events.length; i += size)
    UploadBatch(
      matchId: events.first.matchId,
      events: events.sublist(i, (i + size).clamp(0, events.length)),
    ),
];

/// Uploads all of [events] for [user], in order, and returns the last ack.
Future<SyncAck> uploadAll(
  SyncService service,
  AuthUser user,
  List<EventEnvelope> events,
) async {
  late SyncAck ack;
  for (final batch in batches(events)) {
    ack = await service.upload(user, batch);
  }
  return ack;
}

/// A store whose writes of events fail [failures] times, as when a
/// connection drops partway through a batch.
final class FlakyStore implements ServerStore {
  FlakyStore(this.inner, {required this.failures});

  final MemoryStore inner;
  int failures;

  @override
  Future<T> transaction<T>(
    List<String> userIds,
    Future<T> Function(StoreTransaction tx) body,
  ) => inner.transaction(userIds, (tx) => body(_Flaky(tx, this)));
}

final class _Flaky implements StoreTransaction {
  _Flaky(this._tx, this._store);
  final StoreTransaction _tx;
  final FlakyStore _store;

  @override
  Future<void> addEvents(
    String matchId,
    String userId,
    List<EventEnvelope> events,
  ) async {
    await _tx.addEvents(matchId, userId, events);
    if (_store.failures > 0) {
      _store.failures--;
      throw StateError('the connection dropped');
    }
  }

  @override
  Future<String?> profileOwner(String profileId) => _tx.profileOwner(profileId);
  @override
  Future<void> bindProfile({
    required String profileId,
    required String userId,
    required String deviceId,
  }) =>
      _tx.bindProfile(profileId: profileId, userId: userId, deviceId: deviceId);
  @override
  Future<void> rebindProfiles({
    required String fromUserId,
    required String toUserId,
  }) => _tx.rebindProfiles(fromUserId: fromUserId, toUserId: toUserId);
  @override
  Future<StoredMatch?> match(String matchId) => _tx.match(matchId);
  @override
  Future<void> putMatch(StoredMatch match) => _tx.putMatch(match);
  @override
  Future<StoredMatch?> seriesMatch(String seriesId, int match) =>
      _tx.seriesMatch(seriesId, match);
  @override
  Future<void> moveOpenMatches({
    required String fromUserId,
    required String toUserId,
  }) => _tx.moveOpenMatches(fromUserId: fromUserId, toUserId: toUserId);
  @override
  Future<List<EventEnvelope>> events(String matchId) => _tx.events(matchId);
  @override
  Future<bool> hasEvent(String eventId) => _tx.hasEvent(eventId);
  @override
  Future<bool> credit({
    required String userId,
    required int delta,
    required String reason,
    required String refId,
  }) => _tx.credit(userId: userId, delta: delta, reason: reason, refId: refId);
  @override
  Future<int> balance(String userId) => _tx.balance(userId);
  @override
  Future<int> sumOf(String userId, Set<String> reasons) =>
      _tx.sumOf(userId, reasons);
  @override
  Future<bool> claimSignupBonus(String provider, String subjectHash) =>
      _tx.claimSignupBonus(provider, subjectHash);
  @override
  Future<({String toUserId, int coins})?> mergeOf(String userId) =>
      _tx.mergeOf(userId);
  @override
  Future<void> recordMerge({
    required String fromUserId,
    required String toUserId,
    required int coins,
  }) =>
      _tx.recordMerge(fromUserId: fromUserId, toUserId: toUserId, coins: coins);
}

void main() {
  late MemoryStore store;
  late SyncService service;
  final wonSeed = seedWhere(won: true);
  final wonLog = playMatch(seed: wonSeed, stake: 1000);
  final wonCoins = coinsOf(wonLog);

  setUp(() {
    store = MemoryStore();
    service = SyncService(store: store);
  });

  int ledgerTotal(String userId) => store.ledger
      .where((e) => e.userId == userId)
      .fold(0, (sum, e) => sum + e.delta);

  test('a match uploaded in batches is credited once it is complete', () async {
    final events = chain(wonLog);
    final parts = batches(events);
    expect(parts.length, greaterThan(2));
    final first = await service.upload(guest, parts.first);
    expect(first.status, MatchSyncStatus.open);
    expect(first.ackedSeq, 49);
    expect(first.wallet.balance, Economy.welcomeGift, reason: 'not yet');
    expect(first.wallet.credited, [
      const CoinCredit(CoinReason.welcomeGift, 1000),
    ]);

    final last = await uploadAll(service, guest, events);
    expect(last.status, MatchSyncStatus.accepted);
    expect(last.ackedSeq, events.last.seq);
    expect(last.wallet.balance, 1000 + wonCoins);
    expect(last.wallet.credited, isEmpty, reason: 'the gift is paid once');
    expect(store.matchOf(events.first.matchId)!.coins, wonCoins);
    expect(store.eventsOf(events.first.matchId), hasLength(events.length));
  });

  group('AGENTS.md §9 cases', () {
    test('a duplicate upload changes nothing (ledger idempotency)', () async {
      final events = chain(wonLog);
      await uploadAll(service, guest, events);
      final ledger = [...store.ledger];
      final again = await uploadAll(service, guest, events);
      expect(again.status, MatchSyncStatus.accepted);
      expect(store.ledger, ledger);
      expect(ledgerTotal(guest.id), 1000 + wonCoins);
    });

    test('an interrupted batch is rolled back and sent again', () async {
      final flaky = FlakyStore(MemoryStore(), failures: 1);
      final flakyService = SyncService(store: flaky);
      final events = chain(wonLog);
      final parts = batches(events);
      await expectLater(
        flakyService.upload(guest, parts.first),
        throwsStateError,
      );
      expect(flaky.inner.eventsOf(events.first.matchId), isEmpty);
      expect(flaky.inner.ledger, isEmpty, reason: 'nothing was kept');
      final last = await uploadAll(flakyService, guest, events);
      expect(last.status, MatchSyncStatus.accepted);
      expect(
        flaky.inner.eventsOf(events.first.matchId),
        hasLength(events.length),
      );
    });

    test('a batch that arrives before the one it follows waits', () async {
      final events = chain(wonLog);
      final parts = batches(events);
      final early = await service.upload(guest, parts[1]);
      expect(early.ackedSeq, -1, reason: 'resend from the start');
      expect(store.eventsOf(events.first.matchId), isEmpty);
      await service.upload(guest, parts[0]);
      final late = await service.upload(guest, parts[1]);
      expect(late.ackedSeq, parts[1].events.last.seq);
      final last = await uploadAll(service, guest, events);
      expect(last.status, MatchSyncStatus.accepted);
    });

    test('a tampered chain is rejected, earns nothing, and stays so', () async {
      final events = chain(wonLog);
      final i = events.indexWhere((e) => e.type == 'twentynine.cardPlayed');
      final original = events[i];
      // The payload changes but the hash is copied: the chain breaks.
      events[i] = EventEnvelope(
        eventId: original.eventId,
        matchId: original.matchId,
        seq: original.seq,
        type: original.type,
        actor: original.actor,
        payload: const {'card': '7C'},
        clientTime: original.clientTime,
        userId: original.userId,
        deviceId: original.deviceId,
        gameId: original.gameId,
        rulesVersion: original.rulesVersion,
        appVersion: original.appVersion,
        prevHash: original.prevHash,
        hash: original.hash,
      );
      final ack = await uploadAll(service, guest, events);
      expect(ack.status, MatchSyncStatus.rejected);
      expect(ack.reason, startsWith('broken hash chain'));
      expect(ledgerTotal(guest.id), 1000, reason: 'only the gift');
      final again = await uploadAll(service, guest, chain(wonLog));
      expect(again.status, MatchSyncStatus.rejected, reason: 'flagged');
    });

    test(
      'a valid chain that does not replay is rejected and flagged',
      () async {
        final log = [...wonLog];
        final i = log.indexWhere((e) => e.type == EventTypes.rewardPending);
        log.insert(i, log[i]);
        final ack = await uploadAll(service, guest, chain(log));
        expect(ack.status, MatchSyncStatus.rejected);
        expect(
          ack.reason,
          anyOf(contains('should be'), startsWith('unexpected event')),
        );
        expect(ledgerTotal(guest.id), 1000);
      },
    );

    test('an event that differs from the one held rejects the match', () async {
      final events = chain(wonLog);
      await service.upload(guest, batches(events).first);
      final forked = chain(wonLog);
      final ack = await service.upload(guest, batches(forked).first);
      expect(ack.status, MatchSyncStatus.rejected);
      expect(ack.reason, contains('differs'));
    });
  });

  group('who may upload', () {
    test('a match or profile of another account is refused', () async {
      final events = chain(wonLog);
      await service.upload(guest, batches(events).first);
      await expectLater(
        service.upload(other, batches(events).first),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
      final theirs = chain(
        playMatch(seed: 9),
        matchId: '0199c4a0-0000-7000-8000-000000000009',
      );
      await expectLater(
        service.upload(other, batches(theirs).first),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'not_yours')),
      );
    });

    test('IDs that are not UUIDs are refused', () async {
      final events = chain(playMatch(seed: 5), profileId: 'profile-1');
      await expectLater(
        service.upload(
          guest,
          UploadBatch(
            matchId: events.first.matchId,
            events: events.take(5).toList(),
          ),
        ),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 400)),
      );
    });

    test('rules the server does not have are refused, not stored', () async {
      final events = chain(wonLog, rulesVersion: 99);
      await expectLater(
        service.upload(guest, batches(events).first),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 422)),
      );
      expect(store.matchOf(events.first.matchId), isNull);
    });

    test('a malformed batch is refused', () async {
      final events = chain(wonLog);
      final tooMany = chain(
        List.filled(201, raw('twentynine.passed', 'seat:1')),
      );
      await expectLater(
        service.upload(
          guest,
          UploadBatch(matchId: tooMany.first.matchId, events: tooMany),
        ),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 400)),
        reason: 'more than 200 events',
      );
      await expectLater(
        service.upload(
          guest,
          UploadBatch(
            matchId: '0199c4a0-0000-7000-8000-00000000000f',
            events: events.take(3).toList(),
          ),
        ),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('bonuses (docs/decisions.md D-024)', () {
    test('a Google account gets the sign-up bonus once, ever', () async {
      final first = await service.wallet(googleUser);
      expect(first.credited, [
        const CoinCredit(CoinReason.welcomeGift, 1000),
        const CoinCredit(CoinReason.googleSignupBonus, 2500),
      ]);
      expect(first.balance, 3500);
      expect((await service.wallet(googleUser)).credited, isEmpty);
      // The same Google account on a new Supabase user, as after deleting
      // the account and signing up again: no bonus.
      const again = AuthUser(
        id: 'user-g2',
        isAnonymous: false,
        googleSubject: '1234567890',
      );
      final second = await service.wallet(again);
      expect(second.credited, [const CoinCredit(CoinReason.welcomeGift, 1000)]);
      expect(second.balance, 1000);
      expect((await service.wallet(guest)).balance, 1000, reason: 'guest');
    });

    test('the bonus is kept by a hash, not the Google ID', () {
      final hash = SyncService.subjectHash('google', '1234567890');
      expect(hash, hasLength(64));
      expect(hash, isNot(contains('1234567890')));
    });
  });

  group('merging a guest into a signed-in account (AGENTS.md §10)', () {
    test('moves what the guest won, not its gift', () async {
      await uploadAll(service, guest, chain(wonLog));
      final result = await service.merge(googleUser, guest);
      expect(result.coinsMoved, wonCoins);
      expect(result.wallet.balance, 3500 + wonCoins);
      expect(ledgerTotal(guest.id), 0, reason: 'the guest is closed');
      await expectLater(
        service.wallet(guest),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'merged_account'),
        ),
      );
      final repeat = await service.merge(googleUser, guest);
      expect(repeat.coinsMoved, wonCoins, reason: 'a retry changes nothing');
      expect(ledgerTotal(googleUser.id), 3500 + wonCoins);
    });

    test('moves nothing when the guest lost; never less than zero', () async {
      final lost = playMatch(seed: seedWhere(won: false), stake: 1000);
      await uploadAll(service, guest, chain(lost));
      final result = await service.merge(googleUser, guest);
      expect(result.coinsMoved, 0);
      expect(result.wallet.balance, 3500);
    });

    test('the guest profile and its unfinished match go along', () async {
      final events = chain(wonLog);
      final parts = batches(events);
      await service.upload(guest, parts.first);
      await service.merge(googleUser, guest);
      final last = await uploadAll(service, googleUser, events);
      expect(last.status, MatchSyncStatus.accepted);
      expect(ledgerTotal(googleUser.id), 3500 + wonCoins);
    });

    test('only a guest goes into a signed-in account', () async {
      expect(
        () => service.merge(other, guest),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
      expect(
        () => service.merge(googleUser, googleUser),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 400)),
      );
    });
  });

  group('games (AGENTS.md §6.13, docs/decisions.md D-037)', () {
    final lostSeed = seedWhere(won: false);
    const series = SeriesRef.first('0199c4a0-0000-7000-8000-0000000000e3');
    String matchNo(int n) => '0199c4a0-0000-7000-8000-00000000f00$n';

    /// Match [n] of [series]'s game, which the player's side [won] or not,
    /// starting at [record].
    List<EventEnvelope> gameMatch(
      int n, {
      required bool won,
      required int record,
      bool continueGame = true,
      int stake = 100,
      String? matchId,
    }) => chain(
      playMatch(
        seed: won ? wonSeed : lostSeed,
        stake: stake,
        series: SeriesRef(id: series.id, match: n, record: record),
        continueGame: continueGame,
      ),
      matchId: matchId ?? matchNo(n),
    );

    test("a game's matches are accepted in order; the server counts", () async {
      final first = await uploadAll(
        service,
        guest,
        gameMatch(1, won: true, record: 0),
      );
      expect(first.status, MatchSyncStatus.accepted);
      final stored = store.matchOf(matchNo(1))!;
      expect(
        (stored.seriesId, stored.seriesMatch, stored.recordAfter),
        (series.id, 1, 1),
      );
      expect(stored.seriesContinues, isTrue);

      final second = await uploadAll(
        service,
        guest,
        gameMatch(2, won: false, record: 1, continueGame: false),
      );
      expect(second.status, MatchSyncStatus.accepted);
      expect(store.matchOf(matchNo(2))!.recordAfter, 0);
    });

    test('a match waits for the one before it, then is settled', () async {
      final second = gameMatch(2, won: true, record: 1);
      final early = await uploadAll(service, guest, second);
      expect(early.status, MatchSyncStatus.open);
      expect(early.ackedSeq, second.last.seq, reason: 'held, waiting');

      await uploadAll(service, guest, gameMatch(1, won: true, record: 0));
      // The app sends the last event again to ask.
      final asked = await service.upload(
        guest,
        UploadBatch(matchId: matchNo(2), events: [second.last]),
      );
      expect(asked.status, MatchSyncStatus.accepted);
      expect(store.matchOf(matchNo(2))!.recordAfter, 2);
    });

    test('a record that is not the server\'s count is rejected', () async {
      await uploadAll(service, guest, gameMatch(1, won: false, record: 0));
      final claimed = await uploadAll(
        service,
        guest,
        gameMatch(2, won: true, record: 1),
      );
      expect(claimed.status, MatchSyncStatus.rejected);
      expect(
        claimed.reason,
        'its match record is not the one the server counted',
      );
    });

    test('a game the vote ended takes no more matches', () async {
      await uploadAll(
        service,
        guest,
        gameMatch(1, won: true, record: 0, continueGame: false),
      );
      final more = await uploadAll(
        service,
        guest,
        gameMatch(2, won: true, record: 1),
      );
      expect(more.reason, 'its game had already ended');
    });

    test('a game cannot branch: one match per place', () async {
      await uploadAll(service, guest, gameMatch(1, won: true, record: 0));
      await uploadAll(service, guest, gameMatch(2, won: true, record: 1));
      final branch = await uploadAll(
        service,
        guest,
        gameMatch(
          2,
          won: false,
          record: 1,
          matchId: '0199c4a0-0000-7000-8000-00000000f0b2',
        ),
      );
      expect(branch.status, MatchSyncStatus.rejected);
      expect(branch.reason, 'another match holds its place in the game');
    });

    test('the table may not change within a game', () async {
      await uploadAll(service, guest, gameMatch(1, won: true, record: 0));
      final dearer = await uploadAll(
        service,
        guest,
        gameMatch(2, won: true, record: 1, stake: 500),
      );
      expect(dearer.reason, 'the table changed within its game');
    });

    test('a rejected match rejects the rest of its game', () async {
      // A deal's reward left out: the replay refuses the log.
      final played = playMatch(
        seed: wonSeed,
        series: SeriesRef(id: series.id, match: 1, record: 0),
        continueGame: true,
      );
      final reward = played.indexWhere(
        (e) => e.type == EventTypes.rewardPending,
      );
      await uploadAll(
        service,
        guest,
        chain([...played]..removeAt(reward), matchId: matchNo(1)),
      );
      expect(store.matchOf(matchNo(1))!.status, MatchSyncStatus.rejected);
      final next = await uploadAll(
        service,
        guest,
        gameMatch(2, won: true, record: 1),
      );
      expect(next.reason, 'an earlier match of its game was rejected');
    });

    test('a tied game refunds its fees once; penalties stay', () async {
      await uploadAll(service, guest, gameMatch(1, won: true, record: 0));
      final last = gameMatch(2, won: false, record: 1, continueGame: false);
      await uploadAll(service, guest, last);
      await uploadAll(service, guest, last);
      final refunds = [
        for (final entry in store.ledger)
          if (entry.reason == CoinReason.tieRefund.name) entry.delta,
      ];
      expect(refunds, [200], reason: 'two matches at 100 EC');
      final penalties = [
        for (final entry in store.ledger)
          if (entry.reason == CoinReason.lossPenalty.name) entry.delta,
      ];
      expect(penalties, [-50]);
    });

    test('a guest merging keeps what penalties and refunds came to', () async {
      await uploadAll(
        service,
        guest,
        gameMatch(1, won: false, record: 0, continueGame: false),
      );
      await service.wallet(googleUser);
      final merged = await service.merge(googleUser, guest);
      expect(merged.coinsMoved, 0, reason: 'the guest only lost');
    });
  });
}
