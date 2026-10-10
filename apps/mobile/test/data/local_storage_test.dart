import 'dart:io';

import 'package:card_games/app/version.dart';
import 'package:card_games/data/database_opener.dart';
import 'package:card_games/data/event_log.dart';
import 'package:card_games/data/identity.dart';
import 'package:card_games/data/local_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync_protocol/sync_protocol.dart';

const LocalIdentity alice = LocalIdentity(deviceId: 'phone', userId: 'alice');
const LocalIdentity bob = LocalIdentity(deviceId: 'phone', userId: 'bob');

LocalDatabase memoryDatabase() => LocalDatabase(NativeDatabase.memory());

const List<NewEvent> someEvents = [
  NewEvent(EventTypes.matchCreated, Actors.user, {'seed': '00000000000000ff'}),
  NewEvent('twentynine.bid', 'seat:0', {'value': 16}),
  NewEvent('twentynine.passed', 'seat:1'),
];

void main() {
  group('DriftEventLog', () {
    late LocalDatabase db;
    late DriftEventLog log;

    setUp(() {
      db = memoryDatabase();
      log = DriftEventLog(db, alice, appVersion: appVersion);
    });
    tearDown(() => db.close());

    test('appends events as an intact chain, pending upload', () async {
      await log.append('m1', someEvents, gameId: 'twentynine', rulesVersion: 1);
      await log.append(
        'm1',
        const [NewEvent('twentynine.passed', 'seat:2')],
        gameId: 'twentynine',
        rulesVersion: 1,
      );
      final events = await log.events('m1');
      expect(events.map((e) => e.seq), [0, 1, 2, 3]);
      expect(verifyChain(events), isNull);
      expect(events.first.type, EventTypes.matchCreated);
      expect(events.every((e) => e.userId == 'alice'), isTrue);
      expect(events.every((e) => e.deviceId == 'phone'), isTrue);
      expect(events.every((e) => e.appVersion == appVersion), isTrue);
      final rows = await db.select(db.logEvents).get();
      expect(rows.map((r) => r.syncState).toSet(), {SyncState.pending});
      final match = await db.select(db.matches).getSingle();
      expect(match.lastSeq, 3);
      expect(match.lastHash, events.last.hash);
      expect(match.status, MatchStatus.active);
    });

    test('keeps each user\'s events apart (AGENTS.md §9)', () async {
      await log.append('m1', someEvents, gameId: 'twentynine', rulesVersion: 1);
      final other = DriftEventLog(db, bob, appVersion: appVersion);
      expect(await other.events('m1'), isEmpty);
      expect(await other.unfinishedMatch('twentynine'), isNull);
      expect(
        () => other.append(
          'm1',
          someEvents,
          gameId: 'twentynine',
          rulesVersion: 1,
        ),
        throwsStateError,
      );
    });

    test('finds the newest unfinished match and records its end', () async {
      var now = DateTime.utc(2026);
      final timed = DriftEventLog(db, alice, appVersion: 't', clock: () => now);
      await timed.append(
        'old',
        someEvents,
        gameId: 'twentynine',
        rulesVersion: 1,
      );
      now = DateTime.utc(2026, 2);
      await timed.append(
        'new',
        someEvents,
        gameId: 'twentynine',
        rulesVersion: 1,
      );
      expect(await timed.unfinishedMatch('twentynine'), 'new');
      expect(await timed.unfinishedMatch('other'), isNull);
      await timed.setStatus('new', MatchStatus.finished);
      expect(await timed.unfinishedMatch('twentynine'), 'old');
      await timed.setStatus('old', MatchStatus.abandoned);
      expect(await timed.unfinishedMatch('twentynine'), isNull);
    });
  });

  test('MemoryEventLog behaves like the database log', () async {
    final log = MemoryEventLog(identity: alice);
    await log.append('m1', someEvents, gameId: 'twentynine', rulesVersion: 1);
    final events = await log.events('m1');
    expect(verifyChain(events), isNull);
    expect(await log.unfinishedMatch('twentynine'), 'm1');
    await log.setStatus('m1', MatchStatus.finished);
    expect(log.statusOf('m1'), MatchStatus.finished);
    expect(await log.unfinishedMatch('twentynine'), isNull);
  });

  test('the device and guest IDs are made once and kept', () async {
    final db = memoryDatabase();
    addTearDown(db.close);
    final first = await loadIdentity(db);
    final second = await loadIdentity(db);
    expect(isUuid(first.deviceId), isTrue);
    expect(isUuid(first.userId), isTrue);
    expect(first.deviceId, isNot(first.userId));
    expect(second.deviceId, first.deviceId);
    expect(second.userId, first.userId);
  });

  group('encryption at rest (AGENTS.md §12)', () {
    late Directory folder;
    late File file;
    final key = newDatabaseKey();

    setUp(() {
      folder = Directory.systemTemp.createTempSync('cardgames_db_');
      file = File('${folder.path}/test.db');
    });
    tearDown(() => folder.deleteSync(recursive: true));

    Future<void> writeSecret() async {
      final db = LocalDatabase(
        NativeDatabase(file, setup: (raw) => unlockDatabase(raw, key)),
      );
      await db
          .into(db.meta)
          .insert(MetaCompanion.insert(key: 'k', value: 'SECRET-MARKER'));
      await db.close();
    }

    test('the bundled SQLite can encrypt', () {
      final raw = sqlite3.openInMemory();
      addTearDown(raw.close);
      expect(raw.select('PRAGMA cipher;'), isNotEmpty);
    });

    test('the file is unreadable without the key', () async {
      await writeSecret();
      expect(opensWithKey(file, key), isTrue);
      expect(opensWithKey(file, newDatabaseKey()), isFalse);
      final plain = sqlite3.open(file.path);
      addTearDown(plain.close);
      expect(
        () => plain.select('SELECT * FROM meta;'),
        throwsA(isA<SqliteException>()),
      );
      final bytes = file.readAsBytesSync();
      expect(String.fromCharCodes(bytes).contains('SECRET-MARKER'), isFalse);
    });

    test('a missing file opens with any key', () {
      expect(opensWithKey(File('${folder.path}/none.db'), key), isTrue);
    });

    test('only a 64-digit hex key is accepted', () {
      final raw = sqlite3.openInMemory();
      addTearDown(raw.close);
      expect(
        () => unlockDatabase(raw, "x'; DROP TABLE meta; --"),
        throwsArgumentError,
      );
      expect(() => unlockDatabase(raw, key.toUpperCase()), throwsArgumentError);
    });
  });

  group('database keys', () {
    test('are 256 random bits in hex', () {
      final keys = {for (var i = 0; i < 50; i++) newDatabaseKey()};
      expect(keys, hasLength(50));
      for (final key in keys) {
        expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
      }
    });

    test('are made once and kept in secure storage', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      FlutterSecureStorage.setMockInitialValues({});
      const store = SecureDatabaseKeyStore();
      final first = await store.databaseKey();
      expect(await store.databaseKey(), first);
      FlutterSecureStorage.setMockInitialValues({
        'local_database_key_v1': 'bad',
      });
      final replaced = await store.databaseKey();
      expect(replaced, matches(RegExp(r'^[0-9a-f]{64}$')));
    });
  });

  test('the app version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version: (\S+)$',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(appVersion, version);
  });
}
