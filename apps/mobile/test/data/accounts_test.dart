import 'package:card_games/data/event_log.dart';
import 'package:card_games/data/identity.dart';
import 'package:card_games/data/local_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_protocol/sync_protocol.dart';

const LocalIdentity alice = LocalIdentity(deviceId: 'phone', userId: 'alice');
const LocalIdentity bob = LocalIdentity(deviceId: 'phone', userId: 'bob');

const List<NewEvent> fiveEvents = [
  NewEvent(EventTypes.matchCreated, Actors.user, {'stake': 0}),
  NewEvent('twentynine.bid', 'seat:0', {'value': 16}),
  NewEvent('twentynine.passed', 'seat:1'),
  NewEvent('twentynine.passed', 'seat:2'),
  NewEvent('twentynine.passed', 'seat:3'),
];

void main() {
  group('profiles (AGENTS.md §10)', () {
    late LocalDatabase db;
    setUp(() => db = LocalDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('the first launch makes a guest profile, kept after', () async {
      final first = await loadIdentity(db);
      final again = await loadIdentity(db);
      expect((again.deviceId, again.userId), (first.deviceId, first.userId));
      expect(isUuid(first.userId), isTrue);
      final store = DriftAccountStore(db);
      final profile = await store.active();
      expect(profile.profileId, first.userId);
      expect((profile.kind, profile.remoteUserId), (ProfileKind.guest, null));
    });

    test('profiles are saved, found and switched', () async {
      final store = DriftAccountStore(db);
      final guest = await store.active();
      await store.save(
        guest.copyWith(
          kind: ProfileKind.google,
          remoteUserId: 'remote-1',
          displayName: 'Asha',
          confirmedBalance: 3500,
        ),
      );
      final saved = (await store.byRemoteUser('remote-1'))!;
      expect(
        (
          saved.profileId,
          saved.kind,
          saved.displayName,
          saved.confirmedBalance,
        ),
        (guest.profileId, ProfileKind.google, 'Asha', 3500),
      );
      final next = await store.newGuest();
      expect((await store.active()).profileId, guest.profileId);
      await store.setActive(next.profileId);
      expect((await store.active()).profileId, next.profileId);
      expect((await loadIdentity(db)).userId, next.profileId);
      expect((await store.all()).map((p) => p.profileId), [
        guest.profileId,
        next.profileId,
      ]);
      expect(await store.byRemoteUser('nobody'), isNull);
    });

    test('the memory store behaves the same', () async {
      final store = MemoryAccountStore(guestId: 'g');
      final guest = await store.active();
      await store.save(guest.copyWith(remoteUserId: 'r'));
      expect((await store.byRemoteUser('r'))!.profileId, 'g');
      final next = await store.newGuest();
      await store.setActive(next.profileId);
      expect((await store.active()).isGuest, isTrue);
      expect(() => store.setActive('missing'), throwsStateError);
    });
  });

  group('sync bookkeeping in the event log (AGENTS.md §9)', () {
    late LocalDatabase db;
    setUp(() => db = LocalDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    for (final kind in ['database', 'memory']) {
      test('in the $kind log: acknowledgements and settling', () async {
        var now = DateTime.utc(2026, 10, 9, 8);
        final log = kind == 'database'
            ? DriftEventLog(db, alice, appVersion: 't', clock: () => now)
            : MemoryEventLog(identity: alice);
        await log.append(
          'm1',
          fiveEvents,
          gameId: 'twentynine',
          rulesVersion: 1,
        );
        now = now.add(const Duration(minutes: 1));
        await log.append(
          'm2',
          fiveEvents.take(2).toList(),
          gameId: 'twentynine',
          rulesVersion: 1,
        );
        final states = await log.uploadStates();
        expect(states.map((s) => (s.matchId, s.lastSeq, s.ackedSeq)), [
          ('m1', 4, -1),
          ('m2', 1, -1),
        ]);
        expect((await log.eventsFrom('m1', 2, limit: 2)).map((e) => e.seq), [
          2,
          3,
        ]);

        await log.markAcked('m1', 3);
        await log.markAcked('m1', 1);
        expect(
          (await log.uploadStates()).first.ackedSeq,
          3,
          reason: 'never goes back',
        );

        await log.settle(
          MatchSummary(
            matchId: 'm1',
            gameId: 'twentynine',
            stake: 0,
            result: SettledResult.practice,
            coins: 0,
            settledAt: DateTime.utc(2026, 10, 9, 9),
          ),
        );
        expect(await log.events('m1'), isEmpty);
        expect((await log.uploadStates()).map((s) => s.matchId), ['m2']);
        final summary = (await log.summaries()).single;
        expect(
          (summary.matchId, summary.result, summary.settledAt),
          ('m1', SettledResult.practice, DateTime.utc(2026, 10, 9, 9)),
        );
      });
    }

    test('one profile never sees another\'s matches or summaries', () async {
      final mine = DriftEventLog(db, alice, appVersion: 't');
      final theirs = DriftEventLog(db, bob, appVersion: 't');
      await mine.append(
        'm1',
        fiveEvents,
        gameId: 'twentynine',
        rulesVersion: 1,
      );
      await mine.settle(
        MatchSummary(
          matchId: 'm1',
          gameId: 'twentynine',
          stake: 0,
          result: SettledResult.practice,
          coins: 0,
          settledAt: DateTime.utc(2026),
        ),
      );
      expect(await theirs.summaries(), isEmpty);
      expect(await theirs.uploadStates(), isEmpty);
      await mine.append(
        'm2',
        fiveEvents,
        gameId: 'twentynine',
        rulesVersion: 1,
      );
      await theirs.markAcked('m2', 4);
      expect((await mine.uploadStates()).single.ackedSeq, -1);
      expect(await theirs.eventsFrom('m2', 0), isEmpty);
    });
  });
}
