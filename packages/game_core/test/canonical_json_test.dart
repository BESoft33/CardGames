import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

void main() {
  final sample = {
    'b': [1, true, null, 'x'],
    'a': {'d': 'é', 'c': -5},
  };

  test('sorts object keys and drops whitespace', () {
    expect(
      canonicalJson(sample),
      '{"a":{"c":-5,"d":"é"},"b":[1,true,null,"x"]}',
    );
  });

  test('escapes strings as JSON does', () {
    expect(canonicalJson('a"b\\c\n'), r'"a\"b\\c\n"');
  });

  test('gives equal text for maps built in different orders', () {
    expect(
      canonicalJson({'x': 1, 'y': 2, 'z': 3}),
      canonicalJson({'z': 3, 'x': 1, 'y': 2}),
    );
  });

  test('rejects doubles and other values', () {
    expect(() => canonicalJson(1.5), throwsArgumentError);
    expect(() => canonicalJson({'a': Object()}), throwsArgumentError);
    expect(() => canonicalJson({1: 'a'}), throwsArgumentError);
  });

  test('hashes with SHA-256 of the UTF-8 text', () {
    // Reference digests computed with Python's hashlib.
    expect(
      canonicalHash(sample),
      'e3ae62cfb095c42599d8b858f4c905b66db6ea42b587f21436743d34cbd430e9',
    );
    expect(
      canonicalHash(null),
      '74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',
    );
  });
}
