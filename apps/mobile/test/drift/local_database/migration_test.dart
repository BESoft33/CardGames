import 'package:card_games/data/local_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;

/// Checks each upgrade of the local database against the schema snapshots
/// in drift_schemas/, which `dart run drift_dev make-migrations` keeps up to
/// date (docs/decisions.md D-027). Started from drift's generated template.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  group('every upgrade gives the expected schema', () {
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      for (final toVersion in versions.skip(i + 1)) {
        test('from version $fromVersion to $toVersion', () async {
          final schema = await verifier.schemaAt(fromVersion);
          final db = LocalDatabase(schema.newConnection());
          await verifier.migrateAndValidate(db, toVersion);
          await db.close();
        });
      }
    }
  });

  test('version 1 to 2 keeps the event log, the matches and the IDs', () async {
    const events = [
      v1.LogEventsData(
        eventId: '0199b3a0-0000-7000-8000-000000000001',
        userId: 'guest',
        matchId: 'm1',
        seq: 0,
        type: 'match.created',
        envelope: '{"seq":0}',
        hash: 'h0',
        syncState: 'pending',
      ),
    ];
    const matches = [
      v1.MatchesData(
        matchId: 'm1',
        userId: 'guest',
        gameId: 'twentynine',
        rulesVersion: 1,
        status: 'active',
        lastSeq: 0,
        lastHash: 'h0',
        createdAt: 1759600000000,
        updatedAt: 1759600000000,
      ),
    ];
    const meta = [
      v1.MetaData(key: 'device_id', value: 'device'),
      v1.MetaData(key: 'guest_user_id', value: 'guest'),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: LocalDatabase.new,
      createItems: (batch, oldDb) {
        batch
          ..insertAll(oldDb.logEvents, events)
          ..insertAll(oldDb.matches, matches)
          ..insertAll(oldDb.meta, meta);
      },
      validateItems: (newDb) async {
        expect(await newDb.select(newDb.logEvents).get(), [
          for (final row in events) v2.LogEventsData.fromJson(row.toJson()),
        ]);
        expect(await newDb.select(newDb.matches).get(), [
          for (final row in matches) v2.MatchesData.fromJson(row.toJson()),
        ]);
        expect(await newDb.select(newDb.meta).get(), [
          for (final row in meta) v2.MetaData.fromJson(row.toJson()),
        ]);
        expect(await newDb.select(newDb.settings).get(), isEmpty);
      },
    );
  });

  test('version 2 to 3 makes the first guest the profile in use', () async {
    const meta = [
      v2.MetaData(key: 'device_id', value: 'device'),
      v2.MetaData(key: 'guest_user_id', value: 'guest'),
    ];
    const matches = [
      v2.MatchesData(
        matchId: 'm1',
        userId: 'guest',
        gameId: 'twentynine',
        rulesVersion: 1,
        status: 'finished',
        lastSeq: 40,
        lastHash: 'h40',
        createdAt: 1759600000000,
        updatedAt: 1759600000000,
      ),
    ];
    await verifier.testWithDataIntegrity(
      oldVersion: 2,
      newVersion: 3,
      createOld: v2.DatabaseAtV2.new,
      createNew: v3.DatabaseAtV3.new,
      openTestedDatabase: LocalDatabase.new,
      createItems: (batch, oldDb) {
        batch
          ..insertAll(oldDb.meta, meta)
          ..insertAll(oldDb.matches, matches);
      },
      validateItems: (newDb) async {
        final profile = await newDb.select(newDb.profiles).getSingle();
        expect((profile.profileId, profile.kind), ('guest', 'guest'));
        expect(profile.remoteUserId, isNull);
        expect(profile.confirmedBalance, isNull);
        final active = await (newDb.select(
          newDb.meta,
        )..where((row) => row.key.equals('active_profile_id'))).getSingle();
        expect(active.value, 'guest');
        final match = await newDb.select(newDb.matches).getSingle();
        expect((match.matchId, match.lastSeq, match.ackedSeq), ('m1', 40, -1));
        expect(await newDb.select(newDb.matchSummaries).get(), isEmpty);
      },
    );
  });
}
