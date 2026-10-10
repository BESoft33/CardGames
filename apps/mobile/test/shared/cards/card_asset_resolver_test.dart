import 'dart:io';

import 'package:card_games/app/games.dart';
import 'package:card_games/features/games/twentynine/widgets/table_widgets.dart';
import 'package:card_games/shared/cards/card_asset_resolver.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

/// The asset paths listed under "Missing" in docs/MISSING_ASSETS.md.
Set<String> listedAsMissing(File file) => {
  for (final match in RegExp(
    r'^- (assets/cards/\S+)$',
    multiLine: true,
  ).allMatches(file.readAsStringSync()))
    match.group(1)!,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const resolver = CardAssetResolver();

  group('CardAssetResolver', () {
    test('maps a card to the owner\'s file name', () {
      expect(resolver.face(Card.parse('10S')), 'assets/cards/10_of_spades.png');
      expect(resolver.face(Card.parse('7C')), 'assets/cards/7_of_clubs.png');
      expect(resolver.face(Card.parse('AH')), 'assets/cards/ace_of_hearts.png');
      expect(resolver.face(Card.parse('2D')), 'assets/cards/2_of_diamonds.png');
      expect(resolver.back, 'assets/cards/back.png');
    });

    test('uses the illustrated jacks, queens and kings', () {
      expect(
        resolver.face(Card.parse('JH')),
        'assets/cards/jack_of_hearts2.png',
      );
      expect(
        resolver.face(Card.parse('QS')),
        'assets/cards/queen_of_spades2.png',
      );
      expect(
        resolver.face(Card.parse('KC')),
        'assets/cards/king_of_clubs2.png',
      );
    });

    test('resolves inside the folder it is given', () {
      const other = CardAssetResolver(directory: 'elsewhere');
      expect(other.face(Card.parse('JD')), 'elsewhere/jack_of_diamonds2.png');
      expect(other.back, 'elsewhere/back.png');
      expect(
        other.scoreSix(Suit.hearts, 2),
        'elsewhere/6_of_hearts_2_visible.webp',
      );
    });

    test('names a partly covered six by its suit and pips', () {
      expect(
        resolver.scoreSix(Suit.hearts, 1),
        'assets/cards/6_of_hearts_1_visible.webp',
      );
      expect(
        resolver.scoreSix(Suit.spades, 5),
        'assets/cards/6_of_spades_5_visible.webp',
      );
      expect(
        resolver.scoreSix(Suit.diamonds, 3),
        'assets/cards/6_of_diamonds_3_visible.webp',
      );
      expect(
        resolver.scoreSix(Suit.clubs, 4),
        'assets/cards/6_of_clubs_4_visible.webp',
      );
    });

    test("uses the owner's second version of five of hearts only", () {
      expect(
        resolver.scoreSix(Suit.hearts, 5),
        'assets/cards/6_of_hearts_5_visible_v2.webp',
      );
      for (final suit in [Suit.spades, Suit.diamonds, Suit.clubs]) {
        expect(resolver.scoreSix(suit, 5), endsWith('_5_visible.webp'));
      }
    });

    test('has a partly covered six only for 1 to 5 pips', () {
      for (final pips in [-1, 0, 6, 29]) {
        expect(() => resolver.scoreSix(Suit.hearts, pips), throwsArgumentError);
      }
    });

    test('gives every card and the back a path of its own', () {
      final paths = {
        for (final card in Card.values) resolver.face(card),
        resolver.back,
      };
      expect(paths, hasLength(Card.values.length + 1));
      expect(paths, everyElement(startsWith('assets/cards/')));
    });
  });

  group('Card art for every registered game (AGENTS.md §13)', () {
    late GameRegistry registry;
    late Set<String> required;
    late Set<String> markers;
    late Set<String> declared;
    late Set<String> missing;

    setUpAll(() async {
      registry = ProviderContainer.test().read(gameRegistryProvider);
      required = {
        for (final game in registry.games)
          for (final card in game.deck) resolver.face(card),
        resolver.back,
      };
      // Twenty-Nine's table marks trump with a two, keeps each team's
      // points with its pair of sixes, whole or partly covered, and its
      // match record with a 5 to 2 (AGENTS.md §6.1).
      markers = {
        for (final suit in Suit.values) resolver.face(Card(Rank.two, suit)),
        for (final pair in ScorePair.values)
          for (final suit in [pair.black, pair.red]) ...[
            resolver.face(Card(Rank.six, suit)),
            for (var pips = 1; pips <= CardAssetResolver.maxCoveredPips; pips++)
              resolver.scoreSix(suit, pips),
          ],
        for (final pair in ScorePair.values)
          for (final record in [-4, -3, -2, -1, 1, 2, 3, 4])
            resolver.face(matchCard(pair, record)!),
      };
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      declared = manifest.listAssets().toSet();
      missing = listedAsMissing(File('../../docs/MISSING_ASSETS.md'));
    });

    test('Twenty-Nine is registered and needs 32 faces and a back', () {
      expect(registry.games.map((game) => game.id), ['twentynine']);
      expect(required, hasLength(33));
    });

    test('Twenty-Nine marks trump, points and record with 40 more files', () {
      // The 2s to 5s and the 6s of every suit, and five covered sixes each.
      expect(markers, hasLength(16 + 4 + 20));
      expect(markers.intersection(required), isEmpty);
    });

    test('every file is declared in pubspec.yaml or listed as missing', () {
      final unaccounted = required
          .union(markers)
          .difference(declared)
          .difference(missing);
      expect(
        unaccounted,
        isEmpty,
        reason:
            'Add these files to assets/cards/ or list them in '
            'docs/MISSING_ASSETS.md.',
      );
    });

    test('docs/MISSING_ASSETS.md lists no file that is present', () {
      expect(
        missing.intersection(declared),
        isEmpty,
        reason: 'Remove supplied files from docs/MISSING_ASSETS.md.',
      );
    });

    test('docs/MISSING_ASSETS.md lists only files the game needs', () {
      expect(missing.difference(required.union(markers)), isEmpty);
    });
  });
}
