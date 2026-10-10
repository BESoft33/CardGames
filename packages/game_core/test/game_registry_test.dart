import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

final class _Action implements GameAction {
  const _Action(this.seat);

  @override
  final Seat seat;

  @override
  Map<String, Object?> toJson() => {'seat': seat.index};
}

final class _View implements PlayerView {
  const _View(this.seat);

  @override
  final Seat seat;

  @override
  Map<String, Object?> toJson() => {'seat': seat.index};
}

final class _Game implements GameDefinition<int, _Action, _View> {
  const _Game(this.id);

  @override
  final String id;

  @override
  int get rulesVersion => 1;

  @override
  List<Card> get deck => Card.values;

  @override
  int init(MatchConfig config, int seed) => 0;

  @override
  List<_Action> legalActions(int state, Seat seat) => [_Action(seat)];

  @override
  int apply(int state, _Action action) => state + 1;

  @override
  _View viewFor(int state, Seat seat) => _View(seat);

  @override
  MatchResult? result(int state) => null;
}

void main() {
  test('finds games by ID in registration order', () {
    final registry = GameRegistry([const _Game('a'), const _Game('b')]);
    expect(registry.games.map((g) => g.id), ['a', 'b']);
    expect(registry['b'].id, 'b');
  });

  test('rejects duplicate IDs', () {
    expect(
      () => GameRegistry([const _Game('a'), const _Game('a')]),
      throwsArgumentError,
    );
  });

  test('rejects unknown IDs', () {
    expect(() => GameRegistry([const _Game('a')])['z'], throwsArgumentError);
  });

  test('IllegalActionException explains itself', () {
    const error = IllegalActionException('play 7C', 'not your turn');
    expect(error.toString(), contains('not your turn'));
    expect(error.toString(), contains('play 7C'));
  });
}
