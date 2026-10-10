import 'package:drift/drift.dart';

import 'local_database.steps.dart';

part 'local_database.g.dart';

/// How far an event has got on its way to the server (AGENTS.md §9).
enum SyncState {
  /// Recorded on the device only.
  pending,

  /// Uploaded, not yet acknowledged.
  sent,

  /// Acknowledged by the server.
  acked,

  /// Refused by the server.
  rejected,
}

/// Whether a recorded match is still being played.
enum MatchStatus {
  /// Being played.
  active,

  /// Played to the end.
  finished,

  /// Left before the end.
  abandoned,
}

/// What kind of account a device profile is (AGENTS.md §10).
enum ProfileKind {
  /// A guest: no sign-in, or an anonymous Supabase account.
  guest,

  /// Signed in with Google.
  google,
}

/// How a match the server has settled ended for the player.
enum SettledResult {
  /// The player's side won.
  won,

  /// The player's side lost.
  lost,

  /// The player left; it counts as lost.
  left,

  /// The server could not replay its log; it earned nothing.
  rejected,

  /// A free practice match, which moves no coins.
  practice,
}

/// The local event log: one row per event, never changed once written,
/// except for its sync state.
@DataClassName('LogEventRow')
class LogEvents extends Table {
  TextColumn get eventId => text()();
  TextColumn get userId => text()();
  TextColumn get matchId => text()();
  IntColumn get seq => integer()();
  TextColumn get type => text()();

  /// The whole envelope as canonical JSON, exactly as it will be uploaded.
  TextColumn get envelope => text()();
  TextColumn get hash => text()();
  TextColumn get syncState => textEnum<SyncState>()();

  @override
  Set<Column<Object>> get primaryKey => {eventId};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {matchId, seq},
  ];
}

/// One row per match recorded on the device: where its chain ends.
@DataClassName('MatchRow')
class Matches extends Table {
  TextColumn get matchId => text()();
  TextColumn get userId => text()();
  TextColumn get gameId => text()();
  IntColumn get rulesVersion => integer()();
  TextColumn get status => textEnum<MatchStatus>()();
  IntColumn get lastSeq => integer()();
  TextColumn get lastHash => text()();

  /// The last `seq` the server has acknowledged, or -1 (AGENTS.md §9).
  IntColumn get ackedSeq => integer().withDefault(const Constant(-1))();

  /// Milliseconds since the epoch.
  IntColumn get createdAt => integer()();

  /// Milliseconds since the epoch.
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {matchId};
}

/// Small values the app keeps, such as the device ID.
@DataClassName('MetaRow')
class Meta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Each user's choices, such as the table fee, by key.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get userId => text()();
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {userId, key};
}

/// A profile on this device: a guest, or a signed-in account
/// (AGENTS.md §10). Its ID is the `userId` of the events it logs.
@DataClassName('ProfileRow')
class Profiles extends Table {
  TextColumn get profileId => text()();
  TextColumn get kind => textEnum<ProfileKind>()();

  /// The Supabase user it is bound to, once it has gone online.
  TextColumn get remoteUserId => text().nullable()();

  /// The name to show for a signed-in account, from Google.
  TextColumn get displayName => text().nullable()();

  /// The balance the server last confirmed, or null before the first sync.
  IntColumn get confirmedBalance => integer().nullable()();

  /// Milliseconds since the epoch.
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {profileId};
}

/// What is kept of a match once the server has settled it and its events
/// are deleted (AGENTS.md §9).
@DataClassName('MatchSummaryRow')
class MatchSummaries extends Table {
  TextColumn get matchId => text()();
  TextColumn get userId => text()();
  TextColumn get gameId => text()();
  IntColumn get stake => integer()();
  TextColumn get result => textEnum<SettledResult>()();

  /// The coins it moved: fee and rewards together.
  IntColumn get coins => integer()();

  /// Milliseconds since the epoch.
  IntColumn get settledAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {matchId};
}

/// The app's local database, encrypted at rest (AGENTS.md §12).
///
/// After changing a table, raise [schemaVersion], run
/// `dart run drift_dev make-migrations` and add the step it asks for
/// (docs/decisions.md D-027).
@DriftDatabase(
  tables: [LogEvents, Matches, Meta, Settings, Profiles, MatchSummaries],
)
class LocalDatabase extends _$LocalDatabase {
  /// Opens the database on [executor].
  LocalDatabase(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.createTable(schema.settings);
      },
      from2To3: (m, schema) async {
        await m.createTable(schema.profiles);
        await m.createTable(schema.matchSummaries);
        await m.addColumn(schema.matches, schema.matches.ackedSeq);
        // The guest made on first launch becomes the first profile, and the
        // one in use (docs/decisions.md D-030).
        await customStatement(
          'INSERT INTO profiles (profile_id, kind, created_at) '
          "SELECT value, 'guest', ? FROM meta WHERE key = 'guest_user_id'",
          [DateTime.now().millisecondsSinceEpoch],
        );
        await customStatement(
          "INSERT INTO meta (key, value) SELECT 'active_profile_id', value "
          "FROM meta WHERE key = 'guest_user_id'",
        );
      },
    ),
  );
}
