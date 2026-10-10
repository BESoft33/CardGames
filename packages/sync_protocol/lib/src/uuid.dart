import 'dart:math' as math;

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// Whether [value] is a UUID in lowercase hex with dashes.
bool isUuid(String value) => _uuidPattern.hasMatch(value);

/// A version 7 UUID (RFC 9562): 48 bits of Unix time in milliseconds, then
/// 74 random bits. IDs made later sort later, which keeps log keys ordered.
String uuidV7({DateTime? now, math.Random? random}) {
  final source = random ?? math.Random.secure();
  final time = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final bytes = List<int>.filled(16, 0);
  for (var i = 0; i < 6; i++) {
    bytes[i] = (time >> (8 * (5 - i))) & 0xFF;
  }
  for (var i = 6; i < 16; i++) {
    bytes[i] = source.nextInt(256);
  }
  bytes[6] = 0x70 | (bytes[6] & 0x0F); // version 7
  bytes[8] = 0x80 | (bytes[8] & 0x3F); // RFC 9562 variant
  final hex = [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')]
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// The time stamped in a version 7 UUID made by [uuidV7].
DateTime uuidV7Time(String uuid) {
  final hex = uuid.replaceAll('-', '').substring(0, 12);
  return DateTime.fromMillisecondsSinceEpoch(
    int.parse(hex, radix: 16),
    isUtc: true,
  );
}
