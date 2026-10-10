import 'dart:math' as math;

/// SplitMix64 (Steele, Lea and Flood, 2014). Expands one 64-bit seed into a
/// stream of well-mixed 64-bit values; used to seed [Xoshiro256StarStar].
final class SplitMix64 {
  /// Starts the stream at [seed].
  SplitMix64(int seed) : _state = seed;

  int _state;

  static const int _gamma = 0x9E3779B97F4A7C15;
  static const int _mix1 = 0xBF58476D1CE4E5B9;
  static const int _mix2 = 0x94D049BB133111EB;

  /// The next value, as a 64-bit two's complement integer.
  int next() {
    _state += _gamma;
    var z = _state;
    z = (z ^ (z >>> 30)) * _mix1;
    z = (z ^ (z >>> 27)) * _mix2;
    return z ^ (z >>> 31);
  }
}

/// xoshiro256** 1.0 (Blackman and Vigna, 2018), the generator behind every
/// shuffle. The sequence is defined by this code, not by the platform, so the
/// same seed gives the same deal on every device and on the server.
///
/// Values are 64-bit two's complement integers, so this needs the Dart VM or
/// native compilation; JavaScript targets are not supported.
final class Xoshiro256StarStar {
  /// Starts from a raw state. The four words must not all be zero.
  Xoshiro256StarStar.fromState(int s0, int s1, int s2, int s3)
    : _s0 = s0,
      _s1 = s1,
      _s2 = s2,
      _s3 = s3 {
    if ((s0 | s1 | s2 | s3) == 0) {
      throw ArgumentError('xoshiro256** state must not be all zero');
    }
  }

  /// Starts from [seed]: the state is the first four [SplitMix64] values of
  /// the seed, as the generator's authors recommend.
  factory Xoshiro256StarStar.seeded(int seed) {
    final mixer = SplitMix64(seed);
    return Xoshiro256StarStar.fromState(
      mixer.next(),
      mixer.next(),
      mixer.next(),
      mixer.next(),
    );
  }

  int _s0;
  int _s1;
  int _s2;
  int _s3;

  static int _rotl(int x, int k) => (x << k) | (x >>> (64 - k));

  /// The next 64 random bits, as a two's complement integer.
  int nextInt64() {
    final result = _rotl(_s1 * 5, 7) * 9;
    final t = _s1 << 17;
    _s2 ^= _s0;
    _s3 ^= _s1;
    _s1 ^= _s2;
    _s0 ^= _s3;
    _s2 ^= t;
    _s3 = _rotl(_s3, 45);
    return result;
  }

  /// The next 32 random bits, from the high half of [nextInt64].
  int nextUint32() => nextInt64() >>> 32;

  /// A uniformly distributed integer from 0 to [bound] - 1.
  ///
  /// [bound] must be between 1 and 2^32. Uses Lemire's multiply-and-reject
  /// method, so every value is exactly equally likely.
  int nextBounded(int bound) {
    RangeError.checkValueInInterval(bound, 1, 0x100000000, 'bound');
    var product = nextUint32() * bound;
    var low = product & 0xFFFFFFFF;
    if (low < bound) {
      final threshold = (0x100000000 - bound) % bound;
      while (low < threshold) {
        product = nextUint32() * bound;
        low = product & 0xFFFFFFFF;
      }
    }
    return product >>> 32;
  }
}

/// Shuffles [items] in place with the Fisher-Yates algorithm, drawing from
/// [rng]. Every order is equally likely.
void shuffleInPlace<T>(List<T> items, Xoshiro256StarStar rng) {
  for (var i = items.length - 1; i > 0; i--) {
    final j = rng.nextBounded(i + 1);
    final held = items[i];
    items[i] = items[j];
    items[j] = held;
  }
}

/// A fresh 64-bit seed from [source], by default the platform's
/// cryptographically secure generator (AGENTS.md §5.3).
int secureSeed([math.Random? source]) {
  final random = source ?? math.Random.secure();
  return (random.nextInt(0x100000000) << 32) | random.nextInt(0x100000000);
}

/// Formats a 64-bit seed as 16 lowercase hex digits, for logs and JSON.
///
/// JSON numbers above 2^53 lose precision in some readers, so seeds are
/// stored as text.
String seedToHex(int seed) =>
    (seed >>> 32).toRadixString(16).padLeft(8, '0') +
    (seed & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');

final RegExp _hexSeed = RegExp(r'^[0-9a-f]{16}$');

/// Parses a seed written by [seedToHex].
int seedFromHex(String hex) {
  if (!_hexSeed.hasMatch(hex)) {
    throw FormatException('Not a 16-digit hex seed', hex);
  }
  return (int.parse(hex.substring(0, 8), radix: 16) << 32) |
      int.parse(hex.substring(8), radix: 16);
}
