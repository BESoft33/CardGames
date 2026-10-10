/// A seat at the table. Seats are numbered from 0 in play order.
final class Seat implements Comparable<Seat> {
  /// The seat numbered [index].
  const Seat(this.index) : assert(index >= 0, 'seat index must be >= 0');

  /// Parses a seat ID such as `seat:2`.
  ///
  /// Throws a [FormatException] if [id] is not a seat ID.
  factory Seat.parse(String id) {
    final match = _idPattern.firstMatch(id);
    if (match == null) throw FormatException('Not a seat ID', id);
    return Seat(int.parse(match.group(1)!));
  }

  static final RegExp _idPattern = RegExp(r'^seat:(0|[1-9][0-9]*)$');

  /// The seat's number in play order.
  final int index;

  /// The seat's ID in logs, for example `seat:2`.
  String get id => 'seat:$index';

  /// The seat [steps] places after this one in play order, at a table of
  /// [seatCount] seats. Negative [steps] count backwards.
  Seat offset(int steps, int seatCount) => Seat((index + steps) % seatCount);

  /// The seat that plays after this one at a table of [seatCount] seats.
  Seat next(int seatCount) => offset(1, seatCount);

  @override
  bool operator ==(Object other) => other is Seat && other.index == index;

  @override
  int get hashCode => index;

  @override
  int compareTo(Seat other) => index.compareTo(other.index);

  @override
  String toString() => id;
}
