import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

const String id = '0199c4a0-0000-7000-8000-00000000c001';

Map<String, Object?> created(Object? series) => {
  'rules': const <String, Object?>{},
  'series': series,
};

void main() {
  group('SeriesRules (AGENTS.md §6.13)', () {
    test('the match played with a 2 showing, at 4 either way, is the last', () {
      expect(SeriesRules.lastMatchRecord, 4);
      expect(
        [for (var r = -4; r <= 4; r++) SeriesRules.isLastMatch(r)],
        [true, false, false, false, false, false, false, false, true],
      );
    });
  });

  group('SeriesRef', () {
    test('a game starts at match 1, level', () {
      const first = SeriesRef.first(id);
      expect((first.match, first.record), (1, 0));
      expect(first.isLastMatch, isFalse);
    });

    test('a win adds one to the record and a loss takes one away', () {
      const first = SeriesRef.first(id);
      expect(
        first.next(won: true, endedByLoss: false),
        const SeriesRef(id: id, match: 2, record: 1),
      );
      expect(
        first
            .next(won: false, endedByLoss: false)
            .next(won: true, endedByLoss: false),
        const SeriesRef(id: id, match: 3, record: 0),
        reason: 'a win cancels a loss',
      );
      expect(first.recordAfter(won: false), -1);
    });

    test('one team shows the match card: the winner after a +6, the loser '
        'after a -6, where the record moved away from level', () {
      const first = SeriesRef.first(id);
      // A win by reaching the target: the winner's red card.
      expect(first.next(won: true, endedByLoss: false).trailing, isFalse);
      // A win by the others reaching minus the target: their black card.
      final second = first.next(won: true, endedByLoss: true);
      expect((second.record, second.trailing), (1, true));
      // Further away: the new match decides again.
      expect(second.next(won: true, endedByLoss: false).trailing, isFalse);
      expect(second.next(won: true, endedByLoss: true).trailing, isTrue);
      // Back toward level: the card stays where it is, one step lower.
      const two = SeriesRef(id: id, match: 3, record: 2, trailing: true);
      final back = two.next(won: false, endedByLoss: false);
      expect((back.record, back.trailing), (1, true));
      // At level there is no card.
      expect(second.next(won: false, endedByLoss: true).trailing, isFalse);
    });

    test('reads what match.created logs', () {
      const ref = SeriesRef(id: id, match: 5, record: -2);
      expect(SeriesRef.fromCreated(created(ref.toJson())), ref);
      const trailing = SeriesRef(id: id, match: 4, record: 1, trailing: true);
      expect(SeriesRef.fromCreated(created(trailing.toJson())), trailing);
      expect(
        SeriesRef.fromCreated(
          created(const {'id': id, 'match': 2, 'record': 1}),
        ).trailing,
        isFalse,
        reason: 'a log without it has the card with the leading team',
      );
      expect(const SeriesRef(id: id, match: 5, record: 4).isLastMatch, isTrue);
    });

    test('refuses a missing or impossible game', () {
      for (final series in <Object?>[
        null,
        {'id': 'not-a-uuid', 'match': 1, 'record': 0},
        {'id': id, 'match': 0, 'record': 0},
        {'id': id, 'match': 1, 'record': 1},
        {'id': id, 'match': 3, 'record': 1},
        {'id': id, 'match': 4, 'record': -5},
        {'id': id, 'match': 7, 'record': 6},
        {'id': id, 'match': '2', 'record': 1},
      ]) {
        expect(
          () => SeriesRef.fromCreated(created(series)),
          throwsFormatException,
          reason: '$series',
        );
      }
    });
  });

  test('the payloads name what happened, never an amount', () {
    expect(SeriesPayloads.vote(continueGame: false), {'continue': false});
    expect(SeriesPayloads.ended(SeriesEnd.vote, record: 0), {
      'reason': 'vote',
      'record': 0,
    });
    expect(SeriesPayloads.abandoned(score: -2), {'score': -2});
    expect(EventTypes.seriesVote, 'series.vote');
    expect(EventTypes.seriesEnded, 'series.ended');
  });
}
