import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:game_core/game_core.dart';

import 'coins.dart';
import 'series.dart';
import 'uuid.dart';

/// The `prevHash` of the first event of every match.
const String genesisHash =
    '0000000000000000000000000000000000000000000000000000000000000000';

/// Event types that belong to no single game.
abstract final class EventTypes {
  /// A match was created: its rules, seats, bot levels and seed.
  static const String matchCreated = 'match.created';

  /// The local player left an unfinished match: they quit the game. The
  /// payload holds their team's score at that moment; see
  /// [SeriesPayloads.abandoned].
  static const String matchAbandoned = 'match.abandoned';

  /// After a match, the user voted whether to play the next match of the
  /// game (AGENTS.md §6.13); see [SeriesPayloads.vote].
  static const String seriesVote = 'series.vote';

  /// The game ended, with its reason and the user's team's match record;
  /// see [SeriesPayloads.ended].
  static const String seriesEnded = 'series.ended';

  /// The user paid a table's fee to join a staked match. The payload names
  /// the stake and the number of seats, never an amount to credit (AGENTS.md
  /// §11); see [EconomyPayloads.entryFee].
  static const String entryFee = 'economy.entryFee';

  /// Coins became due to the user and wait for the server: a deal or the
  /// match was won, or a quit or a tied game returns fees. See
  /// [EconomyPayloads].
  static const String rewardPending = 'economy.rewardPending';

  /// Coins became due from the user and wait for the server: the match was
  /// lost. See [EconomyPayloads.lossPenalty].
  static const String penaltyPending = 'economy.penaltyPending';

  /// Every economy event type: what the wallet reads from a match's log.
  static const List<String> economy = [entryFee, rewardPending, penaltyPending];
}

/// Actors that are not a seat.
abstract final class Actors {
  /// The rules, for events no player caused, such as a trick being won.
  static const String system = 'system';

  /// The signed-in or guest user, for app-level events.
  static const String user = 'user';

  /// The actor ID of [seat], for example `seat:2`.
  static String seat(Seat seat) => seat.id;
}

/// One entry of the event log (AGENTS.md §9).
///
/// Each envelope carries the hash of the one before it in its match, and its
/// own [hash] covers every other field. Changing, dropping or reordering an
/// event breaks the chain, which [verifyChain] detects.
final class EventEnvelope {
  /// Creates an envelope from its fields. Use [EventEnvelope.next] to build
  /// one with a correct hash.
  const EventEnvelope({
    required this.eventId,
    required this.matchId,
    required this.seq,
    required this.type,
    required this.actor,
    required this.payload,
    required this.clientTime,
    required this.userId,
    required this.deviceId,
    required this.gameId,
    required this.rulesVersion,
    required this.appVersion,
    required this.prevHash,
    required this.hash,
  });

  /// Builds the event that follows [prevHash] in a match's chain and
  /// computes its hash. The time is stored to the millisecond, in UTC.
  factory EventEnvelope.next({
    required String eventId,
    required String matchId,
    required int seq,
    required String type,
    required String actor,
    required Map<String, Object?> payload,
    required DateTime clientTime,
    required String userId,
    required String deviceId,
    required String gameId,
    required int rulesVersion,
    required String appVersion,
    required String prevHash,
  }) {
    final time = DateTime.fromMillisecondsSinceEpoch(
      clientTime.millisecondsSinceEpoch,
      isUtc: true,
    ).toIso8601String();
    final unhashed = EventEnvelope(
      eventId: eventId,
      matchId: matchId,
      seq: seq,
      type: type,
      actor: actor,
      payload: payload,
      clientTime: time,
      userId: userId,
      deviceId: deviceId,
      gameId: gameId,
      rulesVersion: rulesVersion,
      appVersion: appVersion,
      prevHash: prevHash,
      hash: '',
    );
    return unhashed._withHash(unhashed.expectedHash);
  }

  /// Reads an envelope written by [toJson].
  ///
  /// Throws a [FormatException] if a field is missing or has the wrong type.
  factory EventEnvelope.fromJson(Map<String, Object?> json) {
    T field<T>(String key) {
      final value = json[key];
      if (value is! T) throw FormatException('Envelope field $key is not $T');
      return value;
    }

    return EventEnvelope(
      eventId: field<String>('eventId'),
      matchId: field<String>('matchId'),
      seq: field<int>('seq'),
      type: field<String>('type'),
      actor: field<String>('actor'),
      payload: field<Map<String, Object?>>('payload'),
      clientTime: field<String>('clientTime'),
      userId: field<String>('userId'),
      deviceId: field<String>('deviceId'),
      gameId: field<String>('gameId'),
      rulesVersion: field<int>('rulesVersion'),
      appVersion: field<String>('appVersion'),
      prevHash: field<String>('prevHash'),
      hash: field<String>('hash'),
    );
  }

  /// The event's ID, a version 7 UUID.
  final String eventId;

  /// The match the event belongs to.
  final String matchId;

  /// The event's position in its match, from 0.
  final int seq;

  /// The event type, for example `twentynine.cardPlayed`.
  final String type;

  /// Who caused the event: `seat:N`, `system` or `user`.
  final String actor;

  /// The event's data.
  final Map<String, Object?> payload;

  /// When the device recorded the event: ISO 8601, UTC, milliseconds.
  final String clientTime;

  /// The user the event belongs to. Logs are kept and uploaded per user.
  final String userId;

  /// The device that recorded the event.
  final String deviceId;

  /// The game, for example `twentynine`.
  final String gameId;

  /// The rules version the match is played under.
  final int rulesVersion;

  /// The app version that recorded the event.
  final String appVersion;

  /// The hash of the previous event in the match, or [genesisHash].
  final String prevHash;

  /// SHA-256 of [prevHash] followed by the canonical JSON of every other
  /// field.
  final String hash;

  /// Every field but [hash], as JSON.
  Map<String, Object?> get unhashedJson => {
    'eventId': eventId,
    'matchId': matchId,
    'seq': seq,
    'type': type,
    'actor': actor,
    'payload': payload,
    'clientTime': clientTime,
    'userId': userId,
    'deviceId': deviceId,
    'gameId': gameId,
    'rulesVersion': rulesVersion,
    'appVersion': appVersion,
    'prevHash': prevHash,
  };

  /// The envelope as JSON, [hash] included.
  Map<String, Object?> toJson() => {...unhashedJson, 'hash': hash};

  /// The hash these fields should have.
  String get expectedHash => sha256
      .convert(utf8.encode(prevHash + canonicalJson(unhashedJson)))
      .toString();

  /// Whether [hash] matches the other fields.
  bool get isIntact => hash == expectedHash;

  EventEnvelope _withHash(String hash) => EventEnvelope(
    eventId: eventId,
    matchId: matchId,
    seq: seq,
    type: type,
    actor: actor,
    payload: payload,
    clientTime: clientTime,
    userId: userId,
    deviceId: deviceId,
    gameId: gameId,
    rulesVersion: rulesVersion,
    appVersion: appVersion,
    prevHash: prevHash,
    hash: hash,
  );
}

/// What is wrong with a match's events, as checked by [verifyChain].
final class ChainProblem {
  /// Creates a problem found at sequence number [seq].
  const ChainProblem(this.seq, this.reason);

  /// The sequence number where the chain breaks.
  final int seq;

  /// What is wrong.
  final String reason;

  @override
  String toString() => 'event $seq: $reason';
}

/// Checks the events of one match, in order: one match and one user,
/// sequence numbers from 0 without gaps, valid IDs, each event linked to the
/// one before, and every hash intact. Returns the first problem, or null.
ChainProblem? verifyChain(List<EventEnvelope> events) {
  var prevHash = genesisHash;
  for (var i = 0; i < events.length; i++) {
    final event = events[i];
    if (event.matchId != events.first.matchId) {
      return ChainProblem(event.seq, 'belongs to another match');
    }
    if (event.userId != events.first.userId) {
      return ChainProblem(event.seq, 'belongs to another user');
    }
    if (event.seq != i) {
      return ChainProblem(event.seq, 'expected sequence number $i');
    }
    if (!isUuid(event.eventId)) {
      return ChainProblem(event.seq, 'event ID is not a UUID');
    }
    if (event.prevHash != prevHash) {
      return ChainProblem(event.seq, 'does not follow the previous event');
    }
    if (!event.isIntact) return ChainProblem(event.seq, 'hash does not match');
    prevHash = event.hash;
  }
  return null;
}
