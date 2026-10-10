import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

/// A chain of [count] events in one match.
List<EventEnvelope> chain(int count, {String matchId = 'm'}) {
  final random = math.Random(1);
  final events = <EventEnvelope>[];
  var prevHash = genesisHash;
  for (var seq = 0; seq < count; seq++) {
    final event = EventEnvelope.next(
      eventId: uuidV7(random: random),
      matchId: matchId,
      seq: seq,
      type: seq == 0 ? EventTypes.matchCreated : 'twentynine.cardPlayed',
      actor: seq == 0 ? Actors.user : Actors.seat(Seat(seq % 4)),
      payload: {'card': 'JH', 'n': seq},
      clientTime: DateTime.utc(2026, 10, 4, 10, 15, 30, 123, 456),
      userId: 'u',
      deviceId: 'd',
      gameId: 'twentynine',
      rulesVersion: 1,
      appVersion: '0.1.0+1',
      prevHash: prevHash,
    );
    events.add(event);
    prevHash = event.hash;
  }
  return events;
}

EventEnvelope edited(EventEnvelope e, {Map<String, Object?>? payload}) =>
    EventEnvelope(
      eventId: e.eventId,
      matchId: e.matchId,
      seq: e.seq,
      type: e.type,
      actor: e.actor,
      payload: payload ?? e.payload,
      clientTime: e.clientTime,
      userId: e.userId,
      deviceId: e.deviceId,
      gameId: e.gameId,
      rulesVersion: e.rulesVersion,
      appVersion: e.appVersion,
      prevHash: e.prevHash,
      hash: e.hash,
    );

void main() {
  group('EventEnvelope', () {
    test('has the fields of AGENTS.md §9 and round-trips through JSON', () {
      final event = chain(1).single;
      final json = event.toJson();
      expect(
        json.keys,
        unorderedEquals([
          'eventId',
          'matchId',
          'seq',
          'type',
          'actor',
          'payload',
          'clientTime',
          'userId',
          'deviceId',
          'gameId',
          'rulesVersion',
          'appVersion',
          'prevHash',
          'hash',
        ]),
      );
      final copy = EventEnvelope.fromJson(json);
      expect(copy.toJson(), json);
      expect(copy.isIntact, isTrue);
    });

    test('stores the time in UTC to the millisecond', () {
      expect(chain(1).single.clientTime, '2026-10-04T10:15:30.123Z');
    });

    test('hashes the previous hash and the canonical JSON of the rest', () {
      final first = chain(1).single;
      expect(first.prevHash, genesisHash);
      expect(first.hash, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(first.hash, first.expectedHash);
    });

    test('fromJson rejects missing or mistyped fields', () {
      final json = chain(1).single.toJson();
      expect(
        () => EventEnvelope.fromJson({...json}..remove('hash')),
        throwsFormatException,
      );
      expect(
        () => EventEnvelope.fromJson({...json, 'seq': '0'}),
        throwsFormatException,
      );
    });
  });

  group('verifyChain', () {
    test('accepts an intact chain', () {
      expect(verifyChain(chain(6)), isNull);
      expect(verifyChain(const []), isNull);
    });

    test('catches an edited payload', () {
      final events = chain(4);
      events[2] = edited(events[2], payload: {'card': 'AS'});
      expect(verifyChain(events)?.seq, 2);
      expect(verifyChain(events)?.reason, contains('hash'));
    });

    test('catches a dropped event', () {
      final events = chain(4)..removeAt(1);
      expect(verifyChain(events)?.reason, contains('sequence'));
    });

    test('catches reordered events', () {
      final events = chain(4);
      final second = events[1];
      events[1] = events[2];
      events[2] = second;
      expect(verifyChain(events), isNotNull);
    });

    test('catches a duplicate', () {
      final events = chain(3);
      events.insert(2, events[1]);
      expect(verifyChain(events), isNotNull);
    });

    test('catches an event from another match', () {
      final events = chain(3)..add(chain(4, matchId: 'other')[3]);
      expect(verifyChain(events)?.reason, contains('another match'));
    });

    test('catches a broken link even when each hash is intact', () {
      final events = chain(3);
      final rewritten = EventEnvelope.next(
        eventId: events[2].eventId,
        matchId: 'm',
        seq: 2,
        type: events[2].type,
        actor: events[2].actor,
        payload: events[2].payload,
        clientTime: DateTime.utc(2026),
        userId: 'u',
        deviceId: 'd',
        gameId: 'twentynine',
        rulesVersion: 1,
        appVersion: '0.1.0+1',
        prevHash: genesisHash,
      );
      expect(rewritten.isIntact, isTrue);
      events[2] = rewritten;
      expect(verifyChain(events)?.reason, contains('previous'));
    });

    test('catches a bad event ID', () {
      final events = chain(2);
      final bad = EventEnvelope.next(
        eventId: 'not-a-uuid',
        matchId: 'm',
        seq: 1,
        type: 'x',
        actor: Actors.system,
        payload: const {},
        clientTime: DateTime.utc(2026),
        userId: 'u',
        deviceId: 'd',
        gameId: 'twentynine',
        rulesVersion: 1,
        appVersion: '0.1.0+1',
        prevHash: events[0].hash,
      );
      expect(verifyChain([events[0], bad])?.reason, contains('UUID'));
    });
  });

  group('uuidV7', () {
    test('is a version 7 UUID with the RFC 9562 variant', () {
      final random = math.Random(2);
      for (var i = 0; i < 200; i++) {
        final id = uuidV7(random: random);
        expect(isUuid(id), isTrue, reason: id);
        expect(id[14], '7');
        expect('89ab', contains(id[19]));
      }
    });

    test('carries its time and sorts by it', () {
      final early = uuidV7(now: DateTime.utc(2026, 1, 1, 0, 0, 0, 5));
      final late = uuidV7(now: DateTime.utc(2026, 1, 1, 0, 0, 0, 6));
      expect(uuidV7Time(early), DateTime.utc(2026, 1, 1, 0, 0, 0, 5));
      expect(early.compareTo(late), lessThan(0));
    });

    test('is different every time', () {
      expect({for (var i = 0; i < 1000; i++) uuidV7()}, hasLength(1000));
    });
  });
}
