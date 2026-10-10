import 'package:card_games/data/event_log.dart';
import 'package:card_games/data/identity.dart';
import 'package:card_games/data/local_database.dart';
import 'package:card_games/data/settings_store.dart';
import 'package:card_games/data/wallet.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_protocol/sync_protocol.dart';

const LocalIdentity alice = LocalIdentity(deviceId: 'phone', userId: 'alice');
const LocalIdentity bob = LocalIdentity(deviceId: 'phone', userId: 'bob');

/// Records a match at [stake] in [log]: the fee, a reward for each of
/// [dealsWon] and, if [won], for the match. A stake of 0 is practice.
Future<void> record(
  EventLog log,
  String matchId, {
  required int stake,
  List<int> dealsWon = const [],
  bool won = false,
  MatchStatus? status,
}) async {
  await log.append(
    matchId,
    [
      NewEvent(EventTypes.matchCreated, Actors.user, {'stake': stake}),
      if (stake > 0)
        NewEvent(
          EventTypes.entryFee,
          Actors.user,
          EconomyPayloads.entryFee(stake: stake, seats: 4, humans: 1),
        ),
      const NewEvent('twentynine.bid', 'seat:0', {'value': 16}),
      for (final deal in dealsWon)
        NewEvent(
          EventTypes.rewardPending,
          Actors.system,
          EconomyPayloads.dealWon(deal),
        ),
      if (won)
        NewEvent(
          EventTypes.rewardPending,
          Actors.system,
          EconomyPayloads.matchWon(winners: 1),
        ),
    ],
    gameId: 'twentynine',
    rulesVersion: 1,
  );
  if (status != null) await log.setStatus(matchId, status);
}

void main() {
  group('LocalWalletRepository (AGENTS.md §11)', () {
    test('a new player has the starting gift, pending', () async {
      final wallet = await LocalWalletRepository(MemoryEventLog()).load();
      expect(wallet.confirmed, isNull, reason: 'no server has confirmed it');
      expect(wallet.pending.single, isA<PendingGift>());
      expect(wallet.pendingTotal, Economy.welcomeGift);
      expect(wallet.spendable, 1000);
      expect(wallet.canPay(1000), isTrue);
      expect(wallet.canPay(5000), isFalse);
    });

    test('each staked match shows its fee and rewards, newest first', () async {
      final log = MemoryEventLog();
      await record(
        log,
        'won',
        stake: 1000,
        dealsWon: [1, 3],
        won: true,
        status: MatchStatus.finished,
      );
      await record(
        log,
        'left',
        stake: 500,
        dealsWon: [2],
        status: MatchStatus.abandoned,
      );
      await record(log, 'lost', stake: 100, status: MatchStatus.finished);
      await record(log, 'playing', stake: 100, dealsWon: [1]);
      await record(log, 'practice', stake: 0, status: MatchStatus.finished);

      final wallet = await LocalWalletRepository(log).load();
      final matches = wallet.pending.whereType<PendingMatch>().toList();
      expect(matches.map((m) => m.matchId), [
        'playing',
        'lost',
        'left',
        'won',
      ], reason: 'practice moves no coins');
      expect(wallet.pending.last, isA<PendingGift>());

      final [playing, lost, left, won] = matches;
      expect((won.stake, won.dealsWon, won.won), (1000, 2, true));
      expect(won.amount, -1000 + 2 * 50 + 2000);
      expect(won.status, MatchStatus.finished);
      expect((left.amount, left.won), (-500 + 25, false));
      expect(left.status, MatchStatus.abandoned);
      expect((lost.amount, lost.dealsWon), (-100, 0));
      expect((playing.amount, playing.status), (-95, MatchStatus.active));
      expect(wallet.spendable, 1000 + 1100 - 475 - 100 - 95);
    });

    test('a broken record earns nothing', () async {
      final log = MemoryEventLog();
      await log.append(
        'bad',
        [
          const NewEvent(EventTypes.matchCreated, Actors.user),
          NewEvent(
            EventTypes.rewardPending,
            Actors.system,
            EconomyPayloads.matchWon(winners: 1),
          ),
        ],
        gameId: 'twentynine',
        rulesVersion: 1,
      );
      final wallet = await LocalWalletRepository(log).load();
      expect(wallet.pending.single, isA<PendingGift>());
    });

    test('a fake wallet returns what it is given', () async {
      final fake = FakeWalletRepository(const Wallet(confirmed: 250));
      expect((await fake.load()).spendable, 250);
      fake.wallet = const Wallet(confirmed: 10, pending: [PendingGift()]);
      expect((await fake.load()).spendable, 1010);
    });
  });

  group('coin matches in the database log', () {
    late LocalDatabase db;
    setUp(() => db = LocalDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('match what the memory log reports, per user', () async {
      var now = DateTime.utc(2026, 10, 5, 9);
      final drift = DriftEventLog(db, alice, appVersion: 't', clock: () => now);
      final memory = MemoryEventLog(identity: alice);
      for (final log in <EventLog>[drift, memory]) {
        await record(log, 'first', stake: 500, dealsWon: [1], won: true);
        await log.setStatus('first', MatchStatus.finished);
        now = now.add(const Duration(hours: 1));
        await record(log, 'practice', stake: 0);
        await record(log, 'second', stake: 100, dealsWon: [2, 4]);
      }
      await record(DriftEventLog(db, bob, appVersion: 't'), 'bobs', stake: 100);

      List<List<Object>> summary(List<CoinMatch> matches) => [
        for (final match in matches)
          [
            match.matchId,
            match.gameId,
            match.status,
            [for (final event in match.events) event.type],
          ],
      ];
      final fromDrift = await drift.coinMatches();
      expect(summary(fromDrift), summary(await memory.coinMatches()));
      expect(fromDrift.map((m) => m.matchId), ['first', 'second']);
      expect(fromDrift.first.status, MatchStatus.finished);
      expect(fromDrift.first.startedAt, DateTime.utc(2026, 10, 5, 9));
      expect(fromDrift.last.events.map((e) => e.seq), [1, 3, 4]);
    });
  });

  group('settings stores', () {
    test('the database keeps each user\'s settings apart', () async {
      final db = LocalDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final mine = DriftSettingsStore(db, 'alice');
      final theirs = DriftSettingsStore(db, 'bob');
      expect(await mine.read('stake'), isNull);
      await mine.write('stake', '500');
      await mine.write('stake', '1000');
      await theirs.write('stake', '100');
      expect(await mine.read('stake'), '1000');
      expect(await theirs.read('stake'), '100');
      expect(await db.select(db.settings).get(), hasLength(2));
    });

    test('the memory store keeps what it is given', () async {
      final store = MemorySettingsStore({'stake': '500'});
      expect(await store.read('stake'), '500');
      await store.write('stake', '100');
      expect(store.values, {'stake': '100'});
    });
  });
}
