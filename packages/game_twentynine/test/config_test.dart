import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:test/test.dart';

void main() {
  group('defaults (AGENTS.md §6.2)', () {
    const config = TwentyNineConfig();

    test('are the Nepal table rules', () {
      expect(config.direction, PlayDirection.counterClockwise);
      expect(config.minBid, 16);
      expect(config.lastTrickPoint, isTrue);
      expect(config.maxBid, 29);
      expect(config.askTrump, AskTrumpRule.optional);
      expect(config.allPass, AllPassRule.dealerMustBid);
      expect(config.pair, isTrue);
      expect(config.doubleRedouble, isTrue);
      expect(config.seventhCard, isTrue);
      expect(config.redealChecks, isTrue);
      expect(config.singleHand, isFalse);
      expect(config.targetGamePoints, 6);
      expect(config.problem, isNull);
    });

    test('an empty rule map means the defaults', () {
      expect(TwentyNineConfig.fromJson(const {}), config);
      expect(TwentyNineConfig.fromMatchConfig(const MatchConfig()), config);
    });
  });

  test('without the last-trick point the highest bid is 28', () {
    expect(const TwentyNineConfig(lastTrickPoint: false).maxBid, 28);
  });

  test('every option round-trips through JSON', () {
    const changed = TwentyNineConfig(
      direction: PlayDirection.clockwise,
      minBid: 15,
      lastTrickPoint: false,
      askTrump: AskTrumpRule.mandatory,
      allPass: AllPassRule.redeal,
      pair: false,
      doubleRedouble: false,
      seventhCard: false,
      redealChecks: false,
      singleHand: true,
      targetGamePoints: 10,
    );
    expect(TwentyNineConfig.fromJson(changed.toJson()), changed);
    expect(TwentyNineConfig.fromMatchConfig(changed.toMatchConfig()), changed);
    expect(changed.toJson(), hasLength(11));
  });

  test('copyWith changes only what it is given', () {
    const config = TwentyNineConfig();
    final changed = config.copyWith(minBid: 15, singleHand: true);
    expect(changed.minBid, 15);
    expect(changed.singleHand, isTrue);
    expect(changed.copyWith(minBid: 16, singleHand: false), config);
    expect(config.copyWith(), config);
  });

  test('equal configs are equal and hash alike', () {
    expect(
      const TwentyNineConfig(pair: false),
      TwentyNineConfig.fromJson(const {'pair': false}),
    );
    expect(
      const TwentyNineConfig(pair: false).hashCode,
      TwentyNineConfig.fromJson(const {'pair': false}).hashCode,
    );
    expect(
      const TwentyNineConfig() == const TwentyNineConfig(pair: false),
      isFalse,
    );
    expect(const TwentyNineConfig().toString(), contains('minBid'));
  });

  group('fromJson rejects', () {
    void rejects(Map<String, Object?> json) => expect(
      () => TwentyNineConfig.fromJson(json),
      throwsFormatException,
      reason: '$json',
    );

    test('unknown keys', () => rejects({'minbid': 16}));
    test('values of the wrong type', () {
      rejects({'minBid': '16'});
      rejects({'pair': 1});
      rejects({'targetGamePoints': 6.0});
    });
    test('unknown enum names', () {
      rejects({'direction': 'anticlockwise'});
      rejects({'askTrump': 'never'});
      rejects({'allPass': 3});
    });
    test('a minimum bid other than 15 or 16', () {
      rejects({'minBid': 14});
      rejects({'minBid': 17});
    });
    test('a match target outside 1 to 20', () {
      rejects({'targetGamePoints': 0});
      rejects({'targetGamePoints': 21});
    });
  });

  test('the engine refuses to start with invalid rules', () {
    expect(
      () => const TwentyNineGame().init(
        const MatchConfig(rules: {'minBid': 20}),
        1,
      ),
      throwsFormatException,
    );
  });
}
