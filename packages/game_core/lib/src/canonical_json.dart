import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Encodes [value] as canonical JSON: object keys sorted by code unit, no
/// whitespace. Equal values always give equal text, so the text can be hashed.
///
/// Accepts null, booleans, integers, strings, lists and maps with string
/// keys. Throws an [ArgumentError] for anything else, including doubles,
/// whose text form is not stable.
String canonicalJson(Object? value) {
  final buffer = StringBuffer();
  _write(buffer, value);
  return buffer.toString();
}

/// The SHA-256 of [canonicalJson] of [value], as 64 lowercase hex digits.
String canonicalHash(Object? value) =>
    sha256.convert(utf8.encode(canonicalJson(value))).toString();

void _write(StringBuffer out, Object? value) {
  switch (value) {
    case null || bool() || int() || String():
      out.write(jsonEncode(value));
    case List<Object?>():
      out.write('[');
      for (var i = 0; i < value.length; i++) {
        if (i > 0) out.write(',');
        _write(out, value[i]);
      }
      out.write(']');
    case Map<String, Object?>():
      final keys = value.keys.toList()..sort();
      out.write('{');
      for (var i = 0; i < keys.length; i++) {
        if (i > 0) out.write(',');
        out
          ..write(jsonEncode(keys[i]))
          ..write(':');
        _write(out, value[keys[i]]);
      }
      out.write('}');
    default:
      throw ArgumentError.value(
        value,
        'value',
        'canonical JSON takes only null, bool, int, String, List and Map',
      );
  }
}
