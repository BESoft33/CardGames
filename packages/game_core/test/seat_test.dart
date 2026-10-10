import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

void main() {
  test('IDs look like seat:2 and parse back', () {
    expect(const Seat(2).id, 'seat:2');
    expect(const Seat(0).toString(), 'seat:0');
    expect(Seat.parse('seat:3'), const Seat(3));
    expect(Seat.parse('seat:12'), const Seat(12));
  });

  test('parse rejects anything else', () {
    for (final bad in ['', 'seat:', 'seat:-1', 'seat:01', 'Seat:1', '2']) {
      expect(() => Seat.parse(bad), throwsFormatException, reason: bad);
    }
  });

  test('next and offset wrap around the table', () {
    expect(const Seat(3).next(4), const Seat(0));
    expect(const Seat(1).next(4), const Seat(2));
    expect(const Seat(1).offset(2, 4), const Seat(3));
    expect(const Seat(0).offset(-1, 4), const Seat(3));
    expect(const Seat(2).offset(-6, 4), const Seat(0));
  });

  test('equality and ordering follow the index', () {
    expect(const Seat(1), const Seat(1));
    expect(const Seat(1) == const Seat(2), isFalse);
    expect({const Seat(1), Seat.parse('seat:1')}, hasLength(1));
    expect([const Seat(2), const Seat(0)]..sort(), [
      const Seat(0),
      const Seat(2),
    ]);
  });
}
