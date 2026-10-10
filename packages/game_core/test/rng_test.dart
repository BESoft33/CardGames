import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

/// An unsigned 64-bit reference value as Dart's two's complement int.
int u64(String decimal) => BigInt.parse(decimal).toSigned(64).toInt();

/// Pearson's chi-squared statistic for [counts] against an even spread.
double chiSquared(List<int> counts) {
  final total = counts.fold(0, (a, b) => a + b);
  final expected = total / counts.length;
  return counts.fold(0.0, (sum, n) => sum + (n - expected) * (n - expected)) /
      expected;
}

void main() {
  group('SplitMix64', () {
    test('matches the reference implementation', () {
      // Reference values for seed 1234567 from splitmix64.c (Vigna).
      final rng = SplitMix64(1234567);
      expect(
        [for (var i = 0; i < 5; i++) rng.next()],
        [
          u64('6457827717110365317'),
          u64('3203168211198807973'),
          u64('9817491932198370423'),
          u64('4593380528125082431'),
          u64('16408922859458223821'),
        ],
      );
    });
  });

  group('Xoshiro256StarStar', () {
    test('matches the reference implementation', () {
      // Reference values for the raw state [1, 2, 3, 4] from
      // xoshiro256starstar.c (Blackman and Vigna).
      final rng = Xoshiro256StarStar.fromState(1, 2, 3, 4);
      expect(
        [for (var i = 0; i < 10; i++) rng.nextInt64()],
        [
          u64('11520'),
          u64('0'),
          u64('1509978240'),
          u64('1215971899390074240'),
          u64('1216172134540287360'),
          u64('607988272756665600'),
          u64('16172922978634559625'),
          u64('8476171486693032832'),
          u64('10595114339597558777'),
          u64('2904607092377533576'),
        ],
      );
    });

    test('is seeded from the first four SplitMix64 values', () {
      // Cross-checked against an independent Python implementation.
      final zero = Xoshiro256StarStar.seeded(0);
      expect(
        [for (var i = 0; i < 4; i++) zero.nextInt64()],
        [
          u64('11091344671253066420'),
          u64('13793997310169335082'),
          u64('1900383378846508768'),
          u64('7684712102626143532'),
        ],
      );
      final answer = Xoshiro256StarStar.seeded(42);
      expect(
        [for (var i = 0; i < 4; i++) answer.nextInt64()],
        [
          u64('1546998764402558742'),
          u64('6990951692964543102'),
          u64('12544586762248559009'),
          u64('17057574109182124193'),
        ],
      );
    });

    test('rejects an all-zero state', () {
      expect(
        () => Xoshiro256StarStar.fromState(0, 0, 0, 0),
        throwsArgumentError,
      );
    });

    test('nextUint32 is the high half of the 64-bit value', () {
      final a = Xoshiro256StarStar.seeded(7);
      final b = Xoshiro256StarStar.seeded(7);
      for (var i = 0; i < 100; i++) {
        final bits = a.nextUint32();
        expect(bits, b.nextInt64() >>> 32);
        expect(bits, inInclusiveRange(0, 0xFFFFFFFF));
      }
    });
  });

  group('nextBounded', () {
    test('rejects bounds outside 1 to 2^32', () {
      final rng = Xoshiro256StarStar.seeded(1);
      expect(() => rng.nextBounded(0), throwsRangeError);
      expect(() => rng.nextBounded(0x100000001), throwsRangeError);
    });

    test('stays in range', () {
      final rng = Xoshiro256StarStar.seeded(2);
      for (final bound in [1, 2, 3, 7, 32, 1000, 0x7FFFFFFF, 0x100000000]) {
        for (var i = 0; i < 2000; i++) {
          expect(rng.nextBounded(bound), inInclusiveRange(0, bound - 1));
        }
      }
    });

    test('a bound of 1 always gives 0', () {
      final rng = Xoshiro256StarStar.seeded(3);
      expect([
        for (var i = 0; i < 50; i++) rng.nextBounded(1),
      ], everyElement(0));
    });

    test('spreads small bounds evenly', () {
      final rng = Xoshiro256StarStar.seeded(4);
      final counts = List.filled(6, 0);
      for (var i = 0; i < 60000; i++) {
        counts[rng.nextBounded(6)]++;
      }
      // 5 degrees of freedom; 20.52 is the p = 0.001 critical value.
      expect(chiSquared(counts), lessThan(20.52));
    });

    test('stays even when most draws are rejected', () {
      // For 2^31 + 1 almost half of all draws fall in the rejected zone.
      const bound = 0x80000001;
      final rng = Xoshiro256StarStar.seeded(5);
      var low = 0;
      const draws = 20000;
      for (var i = 0; i < draws; i++) {
        final value = rng.nextBounded(bound);
        expect(value, lessThan(bound));
        if (value < bound ~/ 2) low++;
      }
      // Within 5 standard deviations (about 354) of an even split.
      expect((low - draws / 2).abs(), lessThan(354));
    });
  });

  group('shuffleInPlace', () {
    test('keeps every item exactly once', () {
      final deck = List.of(Card.values);
      shuffleInPlace(deck, Xoshiro256StarStar.seeded(6));
      expect(deck.toSet(), Card.values.toSet());
      expect(deck, hasLength(52));
      expect(deck, isNot(orderedEquals(Card.values)));
    });

    test('the same seed gives the same order', () {
      final a = List.of(Card.values);
      final b = List.of(Card.values);
      shuffleInPlace(a, Xoshiro256StarStar.seeded(99));
      shuffleInPlace(b, Xoshiro256StarStar.seeded(99));
      expect(a, orderedEquals(b));
      final c = List.of(Card.values);
      shuffleInPlace(c, Xoshiro256StarStar.seeded(100));
      expect(c, isNot(orderedEquals(a)));
    });

    test('gives all 24 orders of four items equally often', () {
      final rng = Xoshiro256StarStar.seeded(8);
      final counts = <String, int>{};
      for (var i = 0; i < 48000; i++) {
        final items = [0, 1, 2, 3];
        shuffleInPlace(items, rng);
        counts.update(items.join(), (n) => n + 1, ifAbsent: () => 1);
      }
      expect(counts, hasLength(24));
      // 23 degrees of freedom; 49.73 is the p = 0.001 critical value.
      expect(chiSquared(counts.values.toList()), lessThan(49.73));
    });

    test('puts every item in the first and last place equally often', () {
      final rng = Xoshiro256StarStar.seeded(9);
      final first = List.filled(8, 0);
      final last = List.filled(8, 0);
      for (var i = 0; i < 40000; i++) {
        final items = [0, 1, 2, 3, 4, 5, 6, 7];
        shuffleInPlace(items, rng);
        first[items.first]++;
        last[items.last]++;
      }
      // 7 degrees of freedom; 24.32 is the p = 0.001 critical value.
      expect(chiSquared(first), lessThan(24.32));
      expect(chiSquared(last), lessThan(24.32));
    });
  });

  group('seeds', () {
    test('secureSeed combines two 32-bit draws into 64 bits', () {
      final expected = math.Random(11);
      final high = expected.nextInt(0x100000000);
      final low = expected.nextInt(0x100000000);
      expect(secureSeed(math.Random(11)), (high << 32) | low);
    });

    test('secureSeed gives a different seed each time by default', () {
      expect(secureSeed(), isNot(secureSeed()));
    });

    test('hex form round-trips every seed, including negative ones', () {
      for (final seed in [0, 1, -1, 42, 1 << 63, u64('9223372036854775807')]) {
        final hex = seedToHex(seed);
        expect(hex, matches(RegExp(r'^[0-9a-f]{16}$')));
        expect(seedFromHex(hex), seed);
      }
      expect(seedToHex(-1), 'ffffffffffffffff');
      expect(seedToHex(255), '00000000000000ff');
    });

    test('seedFromHex rejects anything else', () {
      for (final bad in [
        '',
        'ff',
        'FFFFFFFFFFFFFFFF',
        '0x00000000000000',
        'g000000000000000',
      ]) {
        expect(() => seedFromHex(bad), throwsFormatException, reason: bad);
      }
    });
  });
}
