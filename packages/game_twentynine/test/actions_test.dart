import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:test/test.dart';

void main() {
  const seat = Seat(2);
  final all = <TwentyNineAction>[
    const Bid(seat, 17),
    const Pass(seat),
    const ChooseTrump(seat, Suit.hearts),
    const CallSeventhCard(seat),
    const Double(seat),
    const NoDouble(seat),
    const Redouble(seat),
    const NoRedouble(seat),
    const DeclareSingleHand(seat),
    const NoSingleHand(seat),
    PlayCard(seat, Card.parse('JH')),
    const AskTrump(seat),
    const DeclarePair(seat),
    const NoPair(seat),
  ];

  test('every action round-trips through JSON', () {
    for (final action in all) {
      final copy = TwentyNineAction.fromJson(action.toJson());
      expect(copy, action);
      expect(copy.hashCode, action.hashCode);
      expect(copy.toJson()['seat'], 2);
    }
  });

  test('every action is recovered from the event that logs it', () {
    for (final action in all) {
      final event = ActionTaken(action);
      expect(
        TwentyNineAction.fromEvent(event.type, event.actor.id, event.payload),
        action,
      );
    }
  });

  test('events the rules produce record no action', () {
    expect(
      TwentyNineAction.fromEvent('twentynine.trickWon', 'system', const {}),
      isNull,
    );
    expect(
      TwentyNineAction.fromEvent('match.created', 'user', const {}),
      isNull,
    );
    expect(
      () => TwentyNineAction.fromEvent(
        'twentynine.cardPlayed',
        'seat:1',
        const {},
      ),
      throwsFormatException,
    );
    expect(
      () => TwentyNineAction.fromEvent('twentynine.passed', 'nobody', const {}),
      throwsFormatException,
    );
  });

  test('types and event names are distinct', () {
    expect(all.map((a) => a.type).toSet(), hasLength(all.length));
    expect(all.map((a) => a.eventName).toSet(), hasLength(all.length));
    expect(PlayCard(seat, Card.parse('JH')).eventName, 'cardPlayed');
  });

  test('carry their data in JSON', () {
    expect(const Bid(seat, 17).toJson(), {
      'type': 'bid',
      'seat': 2,
      'value': 17,
    });
    expect(const ChooseTrump(seat, Suit.clubs).toJson()['suit'], 'C');
    expect(PlayCard(seat, Card.parse('10S')).toJson()['card'], '10S');
  });

  test('are equal only with the same type, seat and data', () {
    expect(const Bid(seat, 17) == const Bid(seat, 18), isFalse);
    expect(const Bid(seat, 17) == const Bid(Seat(1), 17), isFalse);
    expect(const Pass(seat) == const NoDouble(seat), isFalse);
    expect(PlayCard(seat, Card.parse('JH')), PlayCard(seat, Card.parse('JH')));
    expect(
      PlayCard(seat, Card.parse('JH')) == PlayCard(seat, Card.parse('9H')),
      isFalse,
    );
  });

  test('describe themselves', () {
    expect(const Bid(seat, 17).toString(), 'seat:2 bid 17');
    expect(const Pass(seat).toString(), 'seat:2 pass');
  });

  test('events and plays describe themselves for logs', () {
    expect(
      ActionTaken(PlayCard(seat, Card.parse('JH'))).toString(),
      'twentynine.cardPlayed seat:2 {card: JH}',
    );
    expect(
      const DealCancelled(DealCancelReason.allPassed).toString(),
      'twentynine.dealCancelled - {reason: allPassed}',
    );
    expect(TrickPlay(seat, Card.parse('10S')).toString(), 'seat:2 10S');
  });

  test('fromJson rejects malformed actions', () {
    for (final bad in <Map<String, Object?>>[
      {'type': 'bid', 'seat': 4, 'value': 16},
      {'type': 'bid', 'seat': -1, 'value': 16},
      {'type': 'bid', 'seat': '1', 'value': 16},
      {'type': 'bid', 'seat': 1},
      {'type': 'chooseTrump', 'seat': 1, 'suit': 'X'},
      {'type': 'chooseTrump', 'seat': 1},
      {'type': 'playCard', 'seat': 1, 'card': '2Z'},
      {'type': 'playCard', 'seat': 1, 'card': 5},
      {'type': 'shuffle', 'seat': 1},
    ]) {
      expect(
        () => TwentyNineAction.fromJson(bad),
        throwsFormatException,
        reason: '$bad',
      );
    }
  });
}
