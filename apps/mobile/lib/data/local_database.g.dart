// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_database.dart';

// ignore_for_file: type=lint
class $LogEventsTable extends LogEvents
    with TableInfo<$LogEventsTable, LogEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LogEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _envelopeMeta = const VerificationMeta(
    'envelope',
  );
  @override
  late final GeneratedColumn<String> envelope = GeneratedColumn<String>(
    'envelope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SyncState, String> syncState =
      GeneratedColumn<String>(
        'sync_state',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SyncState>($LogEventsTable.$convertersyncState);
  @override
  List<GeneratedColumn> get $columns => [
    eventId,
    userId,
    matchId,
    seq,
    type,
    envelope,
    hash,
    syncState,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'log_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<LogEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('envelope')) {
      context.handle(
        _envelopeMeta,
        envelope.isAcceptableOrUnknown(data['envelope']!, _envelopeMeta),
      );
    } else if (isInserting) {
      context.missing(_envelopeMeta);
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {matchId, seq},
  ];
  @override
  LogEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LogEventRow(
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      matchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      envelope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}envelope'],
      )!,
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      )!,
      syncState: $LogEventsTable.$convertersyncState.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sync_state'],
        )!,
      ),
    );
  }

  @override
  $LogEventsTable createAlias(String alias) {
    return $LogEventsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SyncState, String, String> $convertersyncState =
      const EnumNameConverter<SyncState>(SyncState.values);
}

class LogEventRow extends DataClass implements Insertable<LogEventRow> {
  final String eventId;
  final String userId;
  final String matchId;
  final int seq;
  final String type;

  /// The whole envelope as canonical JSON, exactly as it will be uploaded.
  final String envelope;
  final String hash;
  final SyncState syncState;
  const LogEventRow({
    required this.eventId,
    required this.userId,
    required this.matchId,
    required this.seq,
    required this.type,
    required this.envelope,
    required this.hash,
    required this.syncState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<String>(eventId);
    map['user_id'] = Variable<String>(userId);
    map['match_id'] = Variable<String>(matchId);
    map['seq'] = Variable<int>(seq);
    map['type'] = Variable<String>(type);
    map['envelope'] = Variable<String>(envelope);
    map['hash'] = Variable<String>(hash);
    {
      map['sync_state'] = Variable<String>(
        $LogEventsTable.$convertersyncState.toSql(syncState),
      );
    }
    return map;
  }

  LogEventsCompanion toCompanion(bool nullToAbsent) {
    return LogEventsCompanion(
      eventId: Value(eventId),
      userId: Value(userId),
      matchId: Value(matchId),
      seq: Value(seq),
      type: Value(type),
      envelope: Value(envelope),
      hash: Value(hash),
      syncState: Value(syncState),
    );
  }

  factory LogEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LogEventRow(
      eventId: serializer.fromJson<String>(json['eventId']),
      userId: serializer.fromJson<String>(json['userId']),
      matchId: serializer.fromJson<String>(json['matchId']),
      seq: serializer.fromJson<int>(json['seq']),
      type: serializer.fromJson<String>(json['type']),
      envelope: serializer.fromJson<String>(json['envelope']),
      hash: serializer.fromJson<String>(json['hash']),
      syncState: $LogEventsTable.$convertersyncState.fromJson(
        serializer.fromJson<String>(json['syncState']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<String>(eventId),
      'userId': serializer.toJson<String>(userId),
      'matchId': serializer.toJson<String>(matchId),
      'seq': serializer.toJson<int>(seq),
      'type': serializer.toJson<String>(type),
      'envelope': serializer.toJson<String>(envelope),
      'hash': serializer.toJson<String>(hash),
      'syncState': serializer.toJson<String>(
        $LogEventsTable.$convertersyncState.toJson(syncState),
      ),
    };
  }

  LogEventRow copyWith({
    String? eventId,
    String? userId,
    String? matchId,
    int? seq,
    String? type,
    String? envelope,
    String? hash,
    SyncState? syncState,
  }) => LogEventRow(
    eventId: eventId ?? this.eventId,
    userId: userId ?? this.userId,
    matchId: matchId ?? this.matchId,
    seq: seq ?? this.seq,
    type: type ?? this.type,
    envelope: envelope ?? this.envelope,
    hash: hash ?? this.hash,
    syncState: syncState ?? this.syncState,
  );
  LogEventRow copyWithCompanion(LogEventsCompanion data) {
    return LogEventRow(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      userId: data.userId.present ? data.userId.value : this.userId,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      seq: data.seq.present ? data.seq.value : this.seq,
      type: data.type.present ? data.type.value : this.type,
      envelope: data.envelope.present ? data.envelope.value : this.envelope,
      hash: data.hash.present ? data.hash.value : this.hash,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LogEventRow(')
          ..write('eventId: $eventId, ')
          ..write('userId: $userId, ')
          ..write('matchId: $matchId, ')
          ..write('seq: $seq, ')
          ..write('type: $type, ')
          ..write('envelope: $envelope, ')
          ..write('hash: $hash, ')
          ..write('syncState: $syncState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    eventId,
    userId,
    matchId,
    seq,
    type,
    envelope,
    hash,
    syncState,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LogEventRow &&
          other.eventId == this.eventId &&
          other.userId == this.userId &&
          other.matchId == this.matchId &&
          other.seq == this.seq &&
          other.type == this.type &&
          other.envelope == this.envelope &&
          other.hash == this.hash &&
          other.syncState == this.syncState);
}

class LogEventsCompanion extends UpdateCompanion<LogEventRow> {
  final Value<String> eventId;
  final Value<String> userId;
  final Value<String> matchId;
  final Value<int> seq;
  final Value<String> type;
  final Value<String> envelope;
  final Value<String> hash;
  final Value<SyncState> syncState;
  final Value<int> rowid;
  const LogEventsCompanion({
    this.eventId = const Value.absent(),
    this.userId = const Value.absent(),
    this.matchId = const Value.absent(),
    this.seq = const Value.absent(),
    this.type = const Value.absent(),
    this.envelope = const Value.absent(),
    this.hash = const Value.absent(),
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LogEventsCompanion.insert({
    required String eventId,
    required String userId,
    required String matchId,
    required int seq,
    required String type,
    required String envelope,
    required String hash,
    required SyncState syncState,
    this.rowid = const Value.absent(),
  }) : eventId = Value(eventId),
       userId = Value(userId),
       matchId = Value(matchId),
       seq = Value(seq),
       type = Value(type),
       envelope = Value(envelope),
       hash = Value(hash),
       syncState = Value(syncState);
  static Insertable<LogEventRow> custom({
    Expression<String>? eventId,
    Expression<String>? userId,
    Expression<String>? matchId,
    Expression<int>? seq,
    Expression<String>? type,
    Expression<String>? envelope,
    Expression<String>? hash,
    Expression<String>? syncState,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (userId != null) 'user_id': userId,
      if (matchId != null) 'match_id': matchId,
      if (seq != null) 'seq': seq,
      if (type != null) 'type': type,
      if (envelope != null) 'envelope': envelope,
      if (hash != null) 'hash': hash,
      if (syncState != null) 'sync_state': syncState,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LogEventsCompanion copyWith({
    Value<String>? eventId,
    Value<String>? userId,
    Value<String>? matchId,
    Value<int>? seq,
    Value<String>? type,
    Value<String>? envelope,
    Value<String>? hash,
    Value<SyncState>? syncState,
    Value<int>? rowid,
  }) {
    return LogEventsCompanion(
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      matchId: matchId ?? this.matchId,
      seq: seq ?? this.seq,
      type: type ?? this.type,
      envelope: envelope ?? this.envelope,
      hash: hash ?? this.hash,
      syncState: syncState ?? this.syncState,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (envelope.present) {
      map['envelope'] = Variable<String>(envelope.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(
        $LogEventsTable.$convertersyncState.toSql(syncState.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LogEventsCompanion(')
          ..write('eventId: $eventId, ')
          ..write('userId: $userId, ')
          ..write('matchId: $matchId, ')
          ..write('seq: $seq, ')
          ..write('type: $type, ')
          ..write('envelope: $envelope, ')
          ..write('hash: $hash, ')
          ..write('syncState: $syncState, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MatchesTable extends Matches with TableInfo<$MatchesTable, MatchRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<String> gameId = GeneratedColumn<String>(
    'game_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rulesVersionMeta = const VerificationMeta(
    'rulesVersion',
  );
  @override
  late final GeneratedColumn<int> rulesVersion = GeneratedColumn<int>(
    'rules_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MatchStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<MatchStatus>($MatchesTable.$converterstatus);
  static const VerificationMeta _lastSeqMeta = const VerificationMeta(
    'lastSeq',
  );
  @override
  late final GeneratedColumn<int> lastSeq = GeneratedColumn<int>(
    'last_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastHashMeta = const VerificationMeta(
    'lastHash',
  );
  @override
  late final GeneratedColumn<String> lastHash = GeneratedColumn<String>(
    'last_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ackedSeqMeta = const VerificationMeta(
    'ackedSeq',
  );
  @override
  late final GeneratedColumn<int> ackedSeq = GeneratedColumn<int>(
    'acked_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(-1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    matchId,
    userId,
    gameId,
    rulesVersion,
    status,
    lastSeq,
    lastHash,
    ackedSeq,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'matches';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatchRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    } else if (isInserting) {
      context.missing(_gameIdMeta);
    }
    if (data.containsKey('rules_version')) {
      context.handle(
        _rulesVersionMeta,
        rulesVersion.isAcceptableOrUnknown(
          data['rules_version']!,
          _rulesVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rulesVersionMeta);
    }
    if (data.containsKey('last_seq')) {
      context.handle(
        _lastSeqMeta,
        lastSeq.isAcceptableOrUnknown(data['last_seq']!, _lastSeqMeta),
      );
    } else if (isInserting) {
      context.missing(_lastSeqMeta);
    }
    if (data.containsKey('last_hash')) {
      context.handle(
        _lastHashMeta,
        lastHash.isAcceptableOrUnknown(data['last_hash']!, _lastHashMeta),
      );
    } else if (isInserting) {
      context.missing(_lastHashMeta);
    }
    if (data.containsKey('acked_seq')) {
      context.handle(
        _ackedSeqMeta,
        ackedSeq.isAcceptableOrUnknown(data['acked_seq']!, _ackedSeqMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {matchId};
  @override
  MatchRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatchRow(
      matchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_id'],
      )!,
      rulesVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rules_version'],
      )!,
      status: $MatchesTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      lastSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seq'],
      )!,
      lastHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_hash'],
      )!,
      ackedSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}acked_seq'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MatchesTable createAlias(String alias) {
    return $MatchesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MatchStatus, String, String> $converterstatus =
      const EnumNameConverter<MatchStatus>(MatchStatus.values);
}

class MatchRow extends DataClass implements Insertable<MatchRow> {
  final String matchId;
  final String userId;
  final String gameId;
  final int rulesVersion;
  final MatchStatus status;
  final int lastSeq;
  final String lastHash;

  /// The last `seq` the server has acknowledged, or -1 (AGENTS.md §9).
  final int ackedSeq;

  /// Milliseconds since the epoch.
  final int createdAt;

  /// Milliseconds since the epoch.
  final int updatedAt;
  const MatchRow({
    required this.matchId,
    required this.userId,
    required this.gameId,
    required this.rulesVersion,
    required this.status,
    required this.lastSeq,
    required this.lastHash,
    required this.ackedSeq,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['match_id'] = Variable<String>(matchId);
    map['user_id'] = Variable<String>(userId);
    map['game_id'] = Variable<String>(gameId);
    map['rules_version'] = Variable<int>(rulesVersion);
    {
      map['status'] = Variable<String>(
        $MatchesTable.$converterstatus.toSql(status),
      );
    }
    map['last_seq'] = Variable<int>(lastSeq);
    map['last_hash'] = Variable<String>(lastHash);
    map['acked_seq'] = Variable<int>(ackedSeq);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  MatchesCompanion toCompanion(bool nullToAbsent) {
    return MatchesCompanion(
      matchId: Value(matchId),
      userId: Value(userId),
      gameId: Value(gameId),
      rulesVersion: Value(rulesVersion),
      status: Value(status),
      lastSeq: Value(lastSeq),
      lastHash: Value(lastHash),
      ackedSeq: Value(ackedSeq),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MatchRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatchRow(
      matchId: serializer.fromJson<String>(json['matchId']),
      userId: serializer.fromJson<String>(json['userId']),
      gameId: serializer.fromJson<String>(json['gameId']),
      rulesVersion: serializer.fromJson<int>(json['rulesVersion']),
      status: $MatchesTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      lastSeq: serializer.fromJson<int>(json['lastSeq']),
      lastHash: serializer.fromJson<String>(json['lastHash']),
      ackedSeq: serializer.fromJson<int>(json['ackedSeq']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'matchId': serializer.toJson<String>(matchId),
      'userId': serializer.toJson<String>(userId),
      'gameId': serializer.toJson<String>(gameId),
      'rulesVersion': serializer.toJson<int>(rulesVersion),
      'status': serializer.toJson<String>(
        $MatchesTable.$converterstatus.toJson(status),
      ),
      'lastSeq': serializer.toJson<int>(lastSeq),
      'lastHash': serializer.toJson<String>(lastHash),
      'ackedSeq': serializer.toJson<int>(ackedSeq),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  MatchRow copyWith({
    String? matchId,
    String? userId,
    String? gameId,
    int? rulesVersion,
    MatchStatus? status,
    int? lastSeq,
    String? lastHash,
    int? ackedSeq,
    int? createdAt,
    int? updatedAt,
  }) => MatchRow(
    matchId: matchId ?? this.matchId,
    userId: userId ?? this.userId,
    gameId: gameId ?? this.gameId,
    rulesVersion: rulesVersion ?? this.rulesVersion,
    status: status ?? this.status,
    lastSeq: lastSeq ?? this.lastSeq,
    lastHash: lastHash ?? this.lastHash,
    ackedSeq: ackedSeq ?? this.ackedSeq,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MatchRow copyWithCompanion(MatchesCompanion data) {
    return MatchRow(
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      userId: data.userId.present ? data.userId.value : this.userId,
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      rulesVersion: data.rulesVersion.present
          ? data.rulesVersion.value
          : this.rulesVersion,
      status: data.status.present ? data.status.value : this.status,
      lastSeq: data.lastSeq.present ? data.lastSeq.value : this.lastSeq,
      lastHash: data.lastHash.present ? data.lastHash.value : this.lastHash,
      ackedSeq: data.ackedSeq.present ? data.ackedSeq.value : this.ackedSeq,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatchRow(')
          ..write('matchId: $matchId, ')
          ..write('userId: $userId, ')
          ..write('gameId: $gameId, ')
          ..write('rulesVersion: $rulesVersion, ')
          ..write('status: $status, ')
          ..write('lastSeq: $lastSeq, ')
          ..write('lastHash: $lastHash, ')
          ..write('ackedSeq: $ackedSeq, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    matchId,
    userId,
    gameId,
    rulesVersion,
    status,
    lastSeq,
    lastHash,
    ackedSeq,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatchRow &&
          other.matchId == this.matchId &&
          other.userId == this.userId &&
          other.gameId == this.gameId &&
          other.rulesVersion == this.rulesVersion &&
          other.status == this.status &&
          other.lastSeq == this.lastSeq &&
          other.lastHash == this.lastHash &&
          other.ackedSeq == this.ackedSeq &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MatchesCompanion extends UpdateCompanion<MatchRow> {
  final Value<String> matchId;
  final Value<String> userId;
  final Value<String> gameId;
  final Value<int> rulesVersion;
  final Value<MatchStatus> status;
  final Value<int> lastSeq;
  final Value<String> lastHash;
  final Value<int> ackedSeq;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const MatchesCompanion({
    this.matchId = const Value.absent(),
    this.userId = const Value.absent(),
    this.gameId = const Value.absent(),
    this.rulesVersion = const Value.absent(),
    this.status = const Value.absent(),
    this.lastSeq = const Value.absent(),
    this.lastHash = const Value.absent(),
    this.ackedSeq = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatchesCompanion.insert({
    required String matchId,
    required String userId,
    required String gameId,
    required int rulesVersion,
    required MatchStatus status,
    required int lastSeq,
    required String lastHash,
    this.ackedSeq = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : matchId = Value(matchId),
       userId = Value(userId),
       gameId = Value(gameId),
       rulesVersion = Value(rulesVersion),
       status = Value(status),
       lastSeq = Value(lastSeq),
       lastHash = Value(lastHash),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MatchRow> custom({
    Expression<String>? matchId,
    Expression<String>? userId,
    Expression<String>? gameId,
    Expression<int>? rulesVersion,
    Expression<String>? status,
    Expression<int>? lastSeq,
    Expression<String>? lastHash,
    Expression<int>? ackedSeq,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (matchId != null) 'match_id': matchId,
      if (userId != null) 'user_id': userId,
      if (gameId != null) 'game_id': gameId,
      if (rulesVersion != null) 'rules_version': rulesVersion,
      if (status != null) 'status': status,
      if (lastSeq != null) 'last_seq': lastSeq,
      if (lastHash != null) 'last_hash': lastHash,
      if (ackedSeq != null) 'acked_seq': ackedSeq,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatchesCompanion copyWith({
    Value<String>? matchId,
    Value<String>? userId,
    Value<String>? gameId,
    Value<int>? rulesVersion,
    Value<MatchStatus>? status,
    Value<int>? lastSeq,
    Value<String>? lastHash,
    Value<int>? ackedSeq,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return MatchesCompanion(
      matchId: matchId ?? this.matchId,
      userId: userId ?? this.userId,
      gameId: gameId ?? this.gameId,
      rulesVersion: rulesVersion ?? this.rulesVersion,
      status: status ?? this.status,
      lastSeq: lastSeq ?? this.lastSeq,
      lastHash: lastHash ?? this.lastHash,
      ackedSeq: ackedSeq ?? this.ackedSeq,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (gameId.present) {
      map['game_id'] = Variable<String>(gameId.value);
    }
    if (rulesVersion.present) {
      map['rules_version'] = Variable<int>(rulesVersion.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $MatchesTable.$converterstatus.toSql(status.value),
      );
    }
    if (lastSeq.present) {
      map['last_seq'] = Variable<int>(lastSeq.value);
    }
    if (lastHash.present) {
      map['last_hash'] = Variable<String>(lastHash.value);
    }
    if (ackedSeq.present) {
      map['acked_seq'] = Variable<int>(ackedSeq.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchesCompanion(')
          ..write('matchId: $matchId, ')
          ..write('userId: $userId, ')
          ..write('gameId: $gameId, ')
          ..write('rulesVersion: $rulesVersion, ')
          ..write('status: $status, ')
          ..write('lastSeq: $lastSeq, ')
          ..write('lastHash: $lastHash, ')
          ..write('ackedSeq: $ackedSeq, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MetaTable extends Meta with TableInfo<$MetaTable, MetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $MetaTable createAlias(String alias) {
    return $MetaTable(attachedDatabase, alias);
  }
}

class MetaRow extends DataClass implements Insertable<MetaRow> {
  final String key;
  final String value;
  const MetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaCompanion toCompanion(bool nullToAbsent) {
    return MetaCompanion(key: Value(key), value: Value(value));
  }

  factory MetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  MetaRow copyWith({String? key, String? value}) =>
      MetaRow(key: key ?? this.key, value: value ?? this.value);
  MetaRow copyWithCompanion(MetaCompanion data) {
    return MetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaRow && other.key == this.key && other.value == this.value);
}

class MetaCompanion extends UpdateCompanion<MetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [userId, key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String userId;
  final String key;
  final String value;
  const SettingRow({
    required this.userId,
    required this.key,
    required this.value,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      userId: Value(userId),
      key: Value(key),
      value: Value(value),
    );
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      userId: serializer.fromJson<String>(json['userId']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? userId, String? key, String? value}) =>
      SettingRow(
        userId: userId ?? this.userId,
        key: key ?? this.key,
        value: value ?? this.value,
      );
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      userId: data.userId.present ? data.userId.value : this.userId,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('userId: $userId, ')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.userId == this.userId &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> userId;
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.userId = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String userId,
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? userId,
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? userId,
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      userId: userId ?? this.userId,
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('userId: $userId, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProfilesTable extends Profiles
    with TableInfo<$ProfilesTable, ProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ProfileKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ProfileKind>($ProfilesTable.$converterkind);
  static const VerificationMeta _remoteUserIdMeta = const VerificationMeta(
    'remoteUserId',
  );
  @override
  late final GeneratedColumn<String> remoteUserId = GeneratedColumn<String>(
    'remote_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _confirmedBalanceMeta = const VerificationMeta(
    'confirmedBalance',
  );
  @override
  late final GeneratedColumn<int> confirmedBalance = GeneratedColumn<int>(
    'confirmed_balance',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    kind,
    remoteUserId,
    displayName,
    confirmedBalance,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('remote_user_id')) {
      context.handle(
        _remoteUserIdMeta,
        remoteUserId.isAcceptableOrUnknown(
          data['remote_user_id']!,
          _remoteUserIdMeta,
        ),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('confirmed_balance')) {
      context.handle(
        _confirmedBalanceMeta,
        confirmedBalance.isAcceptableOrUnknown(
          data['confirmed_balance']!,
          _confirmedBalanceMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId};
  @override
  ProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileRow(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      kind: $ProfilesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      remoteUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_user_id'],
      ),
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      confirmedBalance: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}confirmed_balance'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ProfileKind, String, String> $converterkind =
      const EnumNameConverter<ProfileKind>(ProfileKind.values);
}

class ProfileRow extends DataClass implements Insertable<ProfileRow> {
  final String profileId;
  final ProfileKind kind;

  /// The Supabase user it is bound to, once it has gone online.
  final String? remoteUserId;

  /// The name to show for a signed-in account, from Google.
  final String? displayName;

  /// The balance the server last confirmed, or null before the first sync.
  final int? confirmedBalance;

  /// Milliseconds since the epoch.
  final int createdAt;
  const ProfileRow({
    required this.profileId,
    required this.kind,
    this.remoteUserId,
    this.displayName,
    this.confirmedBalance,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    {
      map['kind'] = Variable<String>($ProfilesTable.$converterkind.toSql(kind));
    }
    if (!nullToAbsent || remoteUserId != null) {
      map['remote_user_id'] = Variable<String>(remoteUserId);
    }
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || confirmedBalance != null) {
      map['confirmed_balance'] = Variable<int>(confirmedBalance);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      profileId: Value(profileId),
      kind: Value(kind),
      remoteUserId: remoteUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUserId),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      confirmedBalance: confirmedBalance == null && nullToAbsent
          ? const Value.absent()
          : Value(confirmedBalance),
      createdAt: Value(createdAt),
    );
  }

  factory ProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileRow(
      profileId: serializer.fromJson<String>(json['profileId']),
      kind: $ProfilesTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      remoteUserId: serializer.fromJson<String?>(json['remoteUserId']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      confirmedBalance: serializer.fromJson<int?>(json['confirmedBalance']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'kind': serializer.toJson<String>(
        $ProfilesTable.$converterkind.toJson(kind),
      ),
      'remoteUserId': serializer.toJson<String?>(remoteUserId),
      'displayName': serializer.toJson<String?>(displayName),
      'confirmedBalance': serializer.toJson<int?>(confirmedBalance),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  ProfileRow copyWith({
    String? profileId,
    ProfileKind? kind,
    Value<String?> remoteUserId = const Value.absent(),
    Value<String?> displayName = const Value.absent(),
    Value<int?> confirmedBalance = const Value.absent(),
    int? createdAt,
  }) => ProfileRow(
    profileId: profileId ?? this.profileId,
    kind: kind ?? this.kind,
    remoteUserId: remoteUserId.present ? remoteUserId.value : this.remoteUserId,
    displayName: displayName.present ? displayName.value : this.displayName,
    confirmedBalance: confirmedBalance.present
        ? confirmedBalance.value
        : this.confirmedBalance,
    createdAt: createdAt ?? this.createdAt,
  );
  ProfileRow copyWithCompanion(ProfilesCompanion data) {
    return ProfileRow(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      kind: data.kind.present ? data.kind.value : this.kind,
      remoteUserId: data.remoteUserId.present
          ? data.remoteUserId.value
          : this.remoteUserId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      confirmedBalance: data.confirmedBalance.present
          ? data.confirmedBalance.value
          : this.confirmedBalance,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileRow(')
          ..write('profileId: $profileId, ')
          ..write('kind: $kind, ')
          ..write('remoteUserId: $remoteUserId, ')
          ..write('displayName: $displayName, ')
          ..write('confirmedBalance: $confirmedBalance, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    profileId,
    kind,
    remoteUserId,
    displayName,
    confirmedBalance,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileRow &&
          other.profileId == this.profileId &&
          other.kind == this.kind &&
          other.remoteUserId == this.remoteUserId &&
          other.displayName == this.displayName &&
          other.confirmedBalance == this.confirmedBalance &&
          other.createdAt == this.createdAt);
}

class ProfilesCompanion extends UpdateCompanion<ProfileRow> {
  final Value<String> profileId;
  final Value<ProfileKind> kind;
  final Value<String?> remoteUserId;
  final Value<String?> displayName;
  final Value<int?> confirmedBalance;
  final Value<int> createdAt;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.profileId = const Value.absent(),
    this.kind = const Value.absent(),
    this.remoteUserId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.confirmedBalance = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String profileId,
    required ProfileKind kind,
    this.remoteUserId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.confirmedBalance = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       kind = Value(kind),
       createdAt = Value(createdAt);
  static Insertable<ProfileRow> custom({
    Expression<String>? profileId,
    Expression<String>? kind,
    Expression<String>? remoteUserId,
    Expression<String>? displayName,
    Expression<int>? confirmedBalance,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (kind != null) 'kind': kind,
      if (remoteUserId != null) 'remote_user_id': remoteUserId,
      if (displayName != null) 'display_name': displayName,
      if (confirmedBalance != null) 'confirmed_balance': confirmedBalance,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith({
    Value<String>? profileId,
    Value<ProfileKind>? kind,
    Value<String?>? remoteUserId,
    Value<String?>? displayName,
    Value<int?>? confirmedBalance,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return ProfilesCompanion(
      profileId: profileId ?? this.profileId,
      kind: kind ?? this.kind,
      remoteUserId: remoteUserId ?? this.remoteUserId,
      displayName: displayName ?? this.displayName,
      confirmedBalance: confirmedBalance ?? this.confirmedBalance,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $ProfilesTable.$converterkind.toSql(kind.value),
      );
    }
    if (remoteUserId.present) {
      map['remote_user_id'] = Variable<String>(remoteUserId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (confirmedBalance.present) {
      map['confirmed_balance'] = Variable<int>(confirmedBalance.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('profileId: $profileId, ')
          ..write('kind: $kind, ')
          ..write('remoteUserId: $remoteUserId, ')
          ..write('displayName: $displayName, ')
          ..write('confirmedBalance: $confirmedBalance, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MatchSummariesTable extends MatchSummaries
    with TableInfo<$MatchSummariesTable, MatchSummaryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchSummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<String> gameId = GeneratedColumn<String>(
    'game_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stakeMeta = const VerificationMeta('stake');
  @override
  late final GeneratedColumn<int> stake = GeneratedColumn<int>(
    'stake',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SettledResult, String> result =
      GeneratedColumn<String>(
        'result',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SettledResult>($MatchSummariesTable.$converterresult);
  static const VerificationMeta _coinsMeta = const VerificationMeta('coins');
  @override
  late final GeneratedColumn<int> coins = GeneratedColumn<int>(
    'coins',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _settledAtMeta = const VerificationMeta(
    'settledAt',
  );
  @override
  late final GeneratedColumn<int> settledAt = GeneratedColumn<int>(
    'settled_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    matchId,
    userId,
    gameId,
    stake,
    result,
    coins,
    settledAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'match_summaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatchSummaryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    } else if (isInserting) {
      context.missing(_gameIdMeta);
    }
    if (data.containsKey('stake')) {
      context.handle(
        _stakeMeta,
        stake.isAcceptableOrUnknown(data['stake']!, _stakeMeta),
      );
    } else if (isInserting) {
      context.missing(_stakeMeta);
    }
    if (data.containsKey('coins')) {
      context.handle(
        _coinsMeta,
        coins.isAcceptableOrUnknown(data['coins']!, _coinsMeta),
      );
    } else if (isInserting) {
      context.missing(_coinsMeta);
    }
    if (data.containsKey('settled_at')) {
      context.handle(
        _settledAtMeta,
        settledAt.isAcceptableOrUnknown(data['settled_at']!, _settledAtMeta),
      );
    } else if (isInserting) {
      context.missing(_settledAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {matchId};
  @override
  MatchSummaryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatchSummaryRow(
      matchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_id'],
      )!,
      stake: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stake'],
      )!,
      result: $MatchSummariesTable.$converterresult.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}result'],
        )!,
      ),
      coins: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}coins'],
      )!,
      settledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}settled_at'],
      )!,
    );
  }

  @override
  $MatchSummariesTable createAlias(String alias) {
    return $MatchSummariesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SettledResult, String, String> $converterresult =
      const EnumNameConverter<SettledResult>(SettledResult.values);
}

class MatchSummaryRow extends DataClass implements Insertable<MatchSummaryRow> {
  final String matchId;
  final String userId;
  final String gameId;
  final int stake;
  final SettledResult result;

  /// The coins it moved: fee and rewards together.
  final int coins;

  /// Milliseconds since the epoch.
  final int settledAt;
  const MatchSummaryRow({
    required this.matchId,
    required this.userId,
    required this.gameId,
    required this.stake,
    required this.result,
    required this.coins,
    required this.settledAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['match_id'] = Variable<String>(matchId);
    map['user_id'] = Variable<String>(userId);
    map['game_id'] = Variable<String>(gameId);
    map['stake'] = Variable<int>(stake);
    {
      map['result'] = Variable<String>(
        $MatchSummariesTable.$converterresult.toSql(result),
      );
    }
    map['coins'] = Variable<int>(coins);
    map['settled_at'] = Variable<int>(settledAt);
    return map;
  }

  MatchSummariesCompanion toCompanion(bool nullToAbsent) {
    return MatchSummariesCompanion(
      matchId: Value(matchId),
      userId: Value(userId),
      gameId: Value(gameId),
      stake: Value(stake),
      result: Value(result),
      coins: Value(coins),
      settledAt: Value(settledAt),
    );
  }

  factory MatchSummaryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatchSummaryRow(
      matchId: serializer.fromJson<String>(json['matchId']),
      userId: serializer.fromJson<String>(json['userId']),
      gameId: serializer.fromJson<String>(json['gameId']),
      stake: serializer.fromJson<int>(json['stake']),
      result: $MatchSummariesTable.$converterresult.fromJson(
        serializer.fromJson<String>(json['result']),
      ),
      coins: serializer.fromJson<int>(json['coins']),
      settledAt: serializer.fromJson<int>(json['settledAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'matchId': serializer.toJson<String>(matchId),
      'userId': serializer.toJson<String>(userId),
      'gameId': serializer.toJson<String>(gameId),
      'stake': serializer.toJson<int>(stake),
      'result': serializer.toJson<String>(
        $MatchSummariesTable.$converterresult.toJson(result),
      ),
      'coins': serializer.toJson<int>(coins),
      'settledAt': serializer.toJson<int>(settledAt),
    };
  }

  MatchSummaryRow copyWith({
    String? matchId,
    String? userId,
    String? gameId,
    int? stake,
    SettledResult? result,
    int? coins,
    int? settledAt,
  }) => MatchSummaryRow(
    matchId: matchId ?? this.matchId,
    userId: userId ?? this.userId,
    gameId: gameId ?? this.gameId,
    stake: stake ?? this.stake,
    result: result ?? this.result,
    coins: coins ?? this.coins,
    settledAt: settledAt ?? this.settledAt,
  );
  MatchSummaryRow copyWithCompanion(MatchSummariesCompanion data) {
    return MatchSummaryRow(
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      userId: data.userId.present ? data.userId.value : this.userId,
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      stake: data.stake.present ? data.stake.value : this.stake,
      result: data.result.present ? data.result.value : this.result,
      coins: data.coins.present ? data.coins.value : this.coins,
      settledAt: data.settledAt.present ? data.settledAt.value : this.settledAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatchSummaryRow(')
          ..write('matchId: $matchId, ')
          ..write('userId: $userId, ')
          ..write('gameId: $gameId, ')
          ..write('stake: $stake, ')
          ..write('result: $result, ')
          ..write('coins: $coins, ')
          ..write('settledAt: $settledAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(matchId, userId, gameId, stake, result, coins, settledAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatchSummaryRow &&
          other.matchId == this.matchId &&
          other.userId == this.userId &&
          other.gameId == this.gameId &&
          other.stake == this.stake &&
          other.result == this.result &&
          other.coins == this.coins &&
          other.settledAt == this.settledAt);
}

class MatchSummariesCompanion extends UpdateCompanion<MatchSummaryRow> {
  final Value<String> matchId;
  final Value<String> userId;
  final Value<String> gameId;
  final Value<int> stake;
  final Value<SettledResult> result;
  final Value<int> coins;
  final Value<int> settledAt;
  final Value<int> rowid;
  const MatchSummariesCompanion({
    this.matchId = const Value.absent(),
    this.userId = const Value.absent(),
    this.gameId = const Value.absent(),
    this.stake = const Value.absent(),
    this.result = const Value.absent(),
    this.coins = const Value.absent(),
    this.settledAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatchSummariesCompanion.insert({
    required String matchId,
    required String userId,
    required String gameId,
    required int stake,
    required SettledResult result,
    required int coins,
    required int settledAt,
    this.rowid = const Value.absent(),
  }) : matchId = Value(matchId),
       userId = Value(userId),
       gameId = Value(gameId),
       stake = Value(stake),
       result = Value(result),
       coins = Value(coins),
       settledAt = Value(settledAt);
  static Insertable<MatchSummaryRow> custom({
    Expression<String>? matchId,
    Expression<String>? userId,
    Expression<String>? gameId,
    Expression<int>? stake,
    Expression<String>? result,
    Expression<int>? coins,
    Expression<int>? settledAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (matchId != null) 'match_id': matchId,
      if (userId != null) 'user_id': userId,
      if (gameId != null) 'game_id': gameId,
      if (stake != null) 'stake': stake,
      if (result != null) 'result': result,
      if (coins != null) 'coins': coins,
      if (settledAt != null) 'settled_at': settledAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatchSummariesCompanion copyWith({
    Value<String>? matchId,
    Value<String>? userId,
    Value<String>? gameId,
    Value<int>? stake,
    Value<SettledResult>? result,
    Value<int>? coins,
    Value<int>? settledAt,
    Value<int>? rowid,
  }) {
    return MatchSummariesCompanion(
      matchId: matchId ?? this.matchId,
      userId: userId ?? this.userId,
      gameId: gameId ?? this.gameId,
      stake: stake ?? this.stake,
      result: result ?? this.result,
      coins: coins ?? this.coins,
      settledAt: settledAt ?? this.settledAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (gameId.present) {
      map['game_id'] = Variable<String>(gameId.value);
    }
    if (stake.present) {
      map['stake'] = Variable<int>(stake.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(
        $MatchSummariesTable.$converterresult.toSql(result.value),
      );
    }
    if (coins.present) {
      map['coins'] = Variable<int>(coins.value);
    }
    if (settledAt.present) {
      map['settled_at'] = Variable<int>(settledAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchSummariesCompanion(')
          ..write('matchId: $matchId, ')
          ..write('userId: $userId, ')
          ..write('gameId: $gameId, ')
          ..write('stake: $stake, ')
          ..write('result: $result, ')
          ..write('coins: $coins, ')
          ..write('settledAt: $settledAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDatabase extends GeneratedDatabase {
  _$LocalDatabase(QueryExecutor e) : super(e);
  $LocalDatabaseManager get managers => $LocalDatabaseManager(this);
  late final $LogEventsTable logEvents = $LogEventsTable(this);
  late final $MatchesTable matches = $MatchesTable(this);
  late final $MetaTable meta = $MetaTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $MatchSummariesTable matchSummaries = $MatchSummariesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    logEvents,
    matches,
    meta,
    settings,
    profiles,
    matchSummaries,
  ];
}

typedef $$LogEventsTableCreateCompanionBuilder = LogEventsCompanion Function({
  required String eventId,
  required String userId,
  required String matchId,
  required int seq,
  required String type,
  required String envelope,
  required String hash,
  required SyncState syncState,
  Value<int> rowid,
});
typedef $$LogEventsTableUpdateCompanionBuilder = LogEventsCompanion Function({
  Value<String> eventId,
  Value<String> userId,
  Value<String> matchId,
  Value<int> seq,
  Value<String> type,
  Value<String> envelope,
  Value<String> hash,
  Value<SyncState> syncState,
  Value<int> rowid,
});

class $$LogEventsTableFilterComposer
    extends Composer<_$LocalDatabase, $LogEventsTable> {
  $$LogEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get matchId => $composableBuilder(
    column: $table.matchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get envelope => $composableBuilder(
    column: $table.envelope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SyncState, SyncState, String> get syncState =>
      $composableBuilder(
        column: $table.syncState,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$LogEventsTableOrderingComposer
    extends Composer<_$LocalDatabase, $LogEventsTable> {
  $$LogEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matchId => $composableBuilder(
    column: $table.matchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get envelope => $composableBuilder(
    column: $table.envelope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LogEventsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LogEventsTable> {
  $$LogEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get matchId =>
      $composableBuilder(column: $table.matchId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get envelope =>
      $composableBuilder(column: $table.envelope, builder: (column) => column);

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SyncState, String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);
}

class $$LogEventsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $LogEventsTable,
          LogEventRow,
          $$LogEventsTableFilterComposer,
          $$LogEventsTableOrderingComposer,
          $$LogEventsTableAnnotationComposer,
          $$LogEventsTableCreateCompanionBuilder,
          $$LogEventsTableUpdateCompanionBuilder,
          (
            LogEventRow,
            BaseReferences<_$LocalDatabase, $LogEventsTable, LogEventRow>,
          ),
          LogEventRow,
          PrefetchHooks Function()
        > {
  $$LogEventsTableTableManager(_$LocalDatabase db, $LogEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LogEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LogEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LogEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> eventId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> matchId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> envelope = const Value.absent(),
                Value<String> hash = const Value.absent(),
                Value<SyncState> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LogEventsCompanion(
                eventId: eventId,
                userId: userId,
                matchId: matchId,
                seq: seq,
                type: type,
                envelope: envelope,
                hash: hash,
                syncState: syncState,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String eventId,
                required String userId,
                required String matchId,
                required int seq,
                required String type,
                required String envelope,
                required String hash,
                required SyncState syncState,
                Value<int> rowid = const Value.absent(),
              }) => LogEventsCompanion.insert(
                eventId: eventId,
                userId: userId,
                matchId: matchId,
                seq: seq,
                type: type,
                envelope: envelope,
                hash: hash,
                syncState: syncState,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LogEventsTable, LogEventRow>(table),
                  BaseReferences<_$LocalDatabase, $LogEventsTable, LogEventRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LogEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $LogEventsTable,
      LogEventRow,
      $$LogEventsTableFilterComposer,
      $$LogEventsTableOrderingComposer,
      $$LogEventsTableAnnotationComposer,
      $$LogEventsTableCreateCompanionBuilder,
      $$LogEventsTableUpdateCompanionBuilder,
      (
        LogEventRow,
        BaseReferences<_$LocalDatabase, $LogEventsTable, LogEventRow>,
      ),
      LogEventRow,
      PrefetchHooks Function()
    >;
typedef $$MatchesTableCreateCompanionBuilder = MatchesCompanion Function({
  required String matchId,
  required String userId,
  required String gameId,
  required int rulesVersion,
  required MatchStatus status,
  required int lastSeq,
  required String lastHash,
  Value<int> ackedSeq,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$MatchesTableUpdateCompanionBuilder = MatchesCompanion Function({
  Value<String> matchId,
  Value<String> userId,
  Value<String> gameId,
  Value<int> rulesVersion,
  Value<MatchStatus> status,
  Value<int> lastSeq,
  Value<String> lastHash,
  Value<int> ackedSeq,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$MatchesTableFilterComposer
    extends Composer<_$LocalDatabase, $MatchesTable> {
  $$MatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get matchId => $composableBuilder(
    column: $table.matchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rulesVersion => $composableBuilder(
    column: $table.rulesVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MatchStatus, MatchStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get lastSeq => $composableBuilder(
    column: $table.lastSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastHash => $composableBuilder(
    column: $table.lastHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ackedSeq => $composableBuilder(
    column: $table.ackedSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MatchesTableOrderingComposer
    extends Composer<_$LocalDatabase, $MatchesTable> {
  $$MatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get matchId => $composableBuilder(
    column: $table.matchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rulesVersion => $composableBuilder(
    column: $table.rulesVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeq => $composableBuilder(
    column: $table.lastSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastHash => $composableBuilder(
    column: $table.lastHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ackedSeq => $composableBuilder(
    column: $table.ackedSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MatchesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $MatchesTable> {
  $$MatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get matchId =>
      $composableBuilder(column: $table.matchId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get gameId =>
      $composableBuilder(column: $table.gameId, builder: (column) => column);

  GeneratedColumn<int> get rulesVersion => $composableBuilder(
    column: $table.rulesVersion,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<MatchStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get lastSeq =>
      $composableBuilder(column: $table.lastSeq, builder: (column) => column);

  GeneratedColumn<String> get lastHash =>
      $composableBuilder(column: $table.lastHash, builder: (column) => column);

  GeneratedColumn<int> get ackedSeq =>
      $composableBuilder(column: $table.ackedSeq, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MatchesTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $MatchesTable,
          MatchRow,
          $$MatchesTableFilterComposer,
          $$MatchesTableOrderingComposer,
          $$MatchesTableAnnotationComposer,
          $$MatchesTableCreateCompanionBuilder,
          $$MatchesTableUpdateCompanionBuilder,
          (MatchRow, BaseReferences<_$LocalDatabase, $MatchesTable, MatchRow>),
          MatchRow,
          PrefetchHooks Function()
        > {
  $$MatchesTableTableManager(_$LocalDatabase db, $MatchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> matchId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> gameId = const Value.absent(),
                Value<int> rulesVersion = const Value.absent(),
                Value<MatchStatus> status = const Value.absent(),
                Value<int> lastSeq = const Value.absent(),
                Value<String> lastHash = const Value.absent(),
                Value<int> ackedSeq = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchesCompanion(
                matchId: matchId,
                userId: userId,
                gameId: gameId,
                rulesVersion: rulesVersion,
                status: status,
                lastSeq: lastSeq,
                lastHash: lastHash,
                ackedSeq: ackedSeq,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String matchId,
                required String userId,
                required String gameId,
                required int rulesVersion,
                required MatchStatus status,
                required int lastSeq,
                required String lastHash,
                Value<int> ackedSeq = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MatchesCompanion.insert(
                matchId: matchId,
                userId: userId,
                gameId: gameId,
                rulesVersion: rulesVersion,
                status: status,
                lastSeq: lastSeq,
                lastHash: lastHash,
                ackedSeq: ackedSeq,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MatchesTable, MatchRow>(table),
                  BaseReferences<_$LocalDatabase, $MatchesTable, MatchRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $MatchesTable,
      MatchRow,
      $$MatchesTableFilterComposer,
      $$MatchesTableOrderingComposer,
      $$MatchesTableAnnotationComposer,
      $$MatchesTableCreateCompanionBuilder,
      $$MatchesTableUpdateCompanionBuilder,
      (MatchRow, BaseReferences<_$LocalDatabase, $MatchesTable, MatchRow>),
      MatchRow,
      PrefetchHooks Function()
    >;
typedef $$MetaTableCreateCompanionBuilder = MetaCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$MetaTableUpdateCompanionBuilder = MetaCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$MetaTableFilterComposer extends Composer<_$LocalDatabase, $MetaTable> {
  $$MetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetaTableOrderingComposer
    extends Composer<_$LocalDatabase, $MetaTable> {
  $$MetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetaTableAnnotationComposer
    extends Composer<_$LocalDatabase, $MetaTable> {
  $$MetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $MetaTable,
          MetaRow,
          $$MetaTableFilterComposer,
          $$MetaTableOrderingComposer,
          $$MetaTableAnnotationComposer,
          $$MetaTableCreateCompanionBuilder,
          $$MetaTableUpdateCompanionBuilder,
          (MetaRow, BaseReferences<_$LocalDatabase, $MetaTable, MetaRow>),
          MetaRow,
          PrefetchHooks Function()
        > {
  $$MetaTableTableManager(_$LocalDatabase db, $MetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => MetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => MetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MetaTable, MetaRow>(table),
                  BaseReferences<_$LocalDatabase, $MetaTable, MetaRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $MetaTable,
      MetaRow,
      $$MetaTableFilterComposer,
      $$MetaTableOrderingComposer,
      $$MetaTableAnnotationComposer,
      $$MetaTableCreateCompanionBuilder,
      $$MetaTableUpdateCompanionBuilder,
      (MetaRow, BaseReferences<_$LocalDatabase, $MetaTable, MetaRow>),
      MetaRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String userId,
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> userId,
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$LocalDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$LocalDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$LocalDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$LocalDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(
                userId: userId,
                key: key,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                userId: userId,
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$LocalDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$LocalDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$ProfilesTableCreateCompanionBuilder = ProfilesCompanion Function({
  required String profileId,
  required ProfileKind kind,
  Value<String?> remoteUserId,
  Value<String?> displayName,
  Value<int?> confirmedBalance,
  required int createdAt,
  Value<int> rowid,
});
typedef $$ProfilesTableUpdateCompanionBuilder = ProfilesCompanion Function({
  Value<String> profileId,
  Value<ProfileKind> kind,
  Value<String?> remoteUserId,
  Value<String?> displayName,
  Value<int?> confirmedBalance,
  Value<int> createdAt,
  Value<int> rowid,
});

class $$ProfilesTableFilterComposer
    extends Composer<_$LocalDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ProfileKind, ProfileKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get remoteUserId => $composableBuilder(
    column: $table.remoteUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get confirmedBalance => $composableBuilder(
    column: $table.confirmedBalance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$LocalDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteUserId => $composableBuilder(
    column: $table.remoteUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get confirmedBalance => $composableBuilder(
    column: $table.confirmedBalance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ProfileKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get remoteUserId => $composableBuilder(
    column: $table.remoteUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get confirmedBalance => $composableBuilder(
    column: $table.confirmedBalance,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $ProfilesTable,
          ProfileRow,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (
            ProfileRow,
            BaseReferences<_$LocalDatabase, $ProfilesTable, ProfileRow>,
          ),
          ProfileRow,
          PrefetchHooks Function()
        > {
  $$ProfilesTableTableManager(_$LocalDatabase db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<ProfileKind> kind = const Value.absent(),
                Value<String?> remoteUserId = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<int?> confirmedBalance = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion(
                profileId: profileId,
                kind: kind,
                remoteUserId: remoteUserId,
                displayName: displayName,
                confirmedBalance: confirmedBalance,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required ProfileKind kind,
                Value<String?> remoteUserId = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<int?> confirmedBalance = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion.insert(
                profileId: profileId,
                kind: kind,
                remoteUserId: remoteUserId,
                displayName: displayName,
                confirmedBalance: confirmedBalance,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProfilesTable, ProfileRow>(table),
                  BaseReferences<_$LocalDatabase, $ProfilesTable, ProfileRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $ProfilesTable,
      ProfileRow,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (ProfileRow, BaseReferences<_$LocalDatabase, $ProfilesTable, ProfileRow>),
      ProfileRow,
      PrefetchHooks Function()
    >;
typedef $$MatchSummariesTableCreateCompanionBuilder =
    MatchSummariesCompanion Function({
      required String matchId,
      required String userId,
      required String gameId,
      required int stake,
      required SettledResult result,
      required int coins,
      required int settledAt,
      Value<int> rowid,
    });
typedef $$MatchSummariesTableUpdateCompanionBuilder =
    MatchSummariesCompanion Function({
      Value<String> matchId,
      Value<String> userId,
      Value<String> gameId,
      Value<int> stake,
      Value<SettledResult> result,
      Value<int> coins,
      Value<int> settledAt,
      Value<int> rowid,
    });

class $$MatchSummariesTableFilterComposer
    extends Composer<_$LocalDatabase, $MatchSummariesTable> {
  $$MatchSummariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get matchId => $composableBuilder(
    column: $table.matchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stake => $composableBuilder(
    column: $table.stake,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SettledResult, SettledResult, String>
  get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get coins => $composableBuilder(
    column: $table.coins,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get settledAt => $composableBuilder(
    column: $table.settledAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MatchSummariesTableOrderingComposer
    extends Composer<_$LocalDatabase, $MatchSummariesTable> {
  $$MatchSummariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get matchId => $composableBuilder(
    column: $table.matchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stake => $composableBuilder(
    column: $table.stake,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coins => $composableBuilder(
    column: $table.coins,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get settledAt => $composableBuilder(
    column: $table.settledAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MatchSummariesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $MatchSummariesTable> {
  $$MatchSummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get matchId =>
      $composableBuilder(column: $table.matchId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get gameId =>
      $composableBuilder(column: $table.gameId, builder: (column) => column);

  GeneratedColumn<int> get stake =>
      $composableBuilder(column: $table.stake, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SettledResult, String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<int> get coins =>
      $composableBuilder(column: $table.coins, builder: (column) => column);

  GeneratedColumn<int> get settledAt =>
      $composableBuilder(column: $table.settledAt, builder: (column) => column);
}

class $$MatchSummariesTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $MatchSummariesTable,
          MatchSummaryRow,
          $$MatchSummariesTableFilterComposer,
          $$MatchSummariesTableOrderingComposer,
          $$MatchSummariesTableAnnotationComposer,
          $$MatchSummariesTableCreateCompanionBuilder,
          $$MatchSummariesTableUpdateCompanionBuilder,
          (
            MatchSummaryRow,
            BaseReferences<
              _$LocalDatabase,
              $MatchSummariesTable,
              MatchSummaryRow
            >,
          ),
          MatchSummaryRow,
          PrefetchHooks Function()
        > {
  $$MatchSummariesTableTableManager(
    _$LocalDatabase db,
    $MatchSummariesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatchSummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatchSummariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatchSummariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> matchId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> gameId = const Value.absent(),
                Value<int> stake = const Value.absent(),
                Value<SettledResult> result = const Value.absent(),
                Value<int> coins = const Value.absent(),
                Value<int> settledAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchSummariesCompanion(
                matchId: matchId,
                userId: userId,
                gameId: gameId,
                stake: stake,
                result: result,
                coins: coins,
                settledAt: settledAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String matchId,
                required String userId,
                required String gameId,
                required int stake,
                required SettledResult result,
                required int coins,
                required int settledAt,
                Value<int> rowid = const Value.absent(),
              }) => MatchSummariesCompanion.insert(
                matchId: matchId,
                userId: userId,
                gameId: gameId,
                stake: stake,
                result: result,
                coins: coins,
                settledAt: settledAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MatchSummariesTable, MatchSummaryRow>(table),
                  BaseReferences<
                    _$LocalDatabase,
                    $MatchSummariesTable,
                    MatchSummaryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MatchSummariesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $MatchSummariesTable,
      MatchSummaryRow,
      $$MatchSummariesTableFilterComposer,
      $$MatchSummariesTableOrderingComposer,
      $$MatchSummariesTableAnnotationComposer,
      $$MatchSummariesTableCreateCompanionBuilder,
      $$MatchSummariesTableUpdateCompanionBuilder,
      (
        MatchSummaryRow,
        BaseReferences<_$LocalDatabase, $MatchSummariesTable, MatchSummaryRow>,
      ),
      MatchSummaryRow,
      PrefetchHooks Function()
    >;

class $LocalDatabaseManager {
  final _$LocalDatabase _db;
  $LocalDatabaseManager(this._db);
  $$LogEventsTableTableManager get logEvents =>
      $$LogEventsTableTableManager(_db, _db.logEvents);
  $$MatchesTableTableManager get matches =>
      $$MatchesTableTableManager(_db, _db.matches);
  $$MetaTableTableManager get meta => $$MetaTableTableManager(_db, _db.meta);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$MatchSummariesTableTableManager get matchSummaries =>
      $$MatchSummariesTableTableManager(_db, _db.matchSummaries);
}
