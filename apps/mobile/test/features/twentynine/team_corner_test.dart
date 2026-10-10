import 'package:card_games/features/games/twentynine/widgets/table_widgets.dart';
import 'package:card_games/shared/cards/card_asset_resolver.dart';
import 'package:card_games/shared/cards/playing_card.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

import '../../helpers/pump_app.dart';

Future<void> showCorner(
  WidgetTester tester, {
  ScorePair pair = ScorePair.ours,
  int score = 0,
  int record = 0,
  List<Override> overrides = const [],
}) => pumpInApp(
  tester,
  TeamCorner(
    pair: pair,
    team: pair == ScorePair.ours ? 'Us' : 'Them',
    score: score,
    record: record,
    width: 120,
  ),
  overrides: overrides,
);

Finder get sixes => find.byKey(const ValueKey('sixes'));

/// The asset the corner's own image shows, if it has one.
String? scoreArt(WidgetTester tester) {
  final images = find.descendant(of: sixes, matching: find.byType(Image));
  final provider = tester.widget<Image>(images.first).image;
  final asset = provider is ResizeImage ? provider.imageProvider : provider;
  return (asset as AssetImage).assetName;
}

/// The cards drawn whole among the sixes, left to right.
List<Card?> wholeSixes(WidgetTester tester) {
  final cards = find.descendant(of: sixes, matching: find.byType(PlayingCard));
  final found = cards.evaluate().toList()
    ..sort(
      (a, b) => tester
          .getTopLeft(find.byWidget(a.widget))
          .dx
          .compareTo(tester.getTopLeft(find.byWidget(b.widget)).dx),
    );
  return [for (final element in found) (element.widget as PlayingCard).card];
}

/// The match card shown, if any.
Card? shownMatchCard(WidgetTester tester) {
  final card = find.byKey(const ValueKey('match-card'));
  return card.evaluate().isEmpty ? null : tester.widget<PlayingCard>(card).card;
}

void main() {
  const resolver = CardAssetResolver();

  group('the pair of sixes (AGENTS.md §6.1)', () {
    test('is 6♠ and 6♦ for us, 6♥ and 6♣ for them', () {
      expect(
        (ScorePair.ours.black, ScorePair.ours.red),
        (Suit.spades, Suit.diamonds),
      );
      expect(
        (ScorePair.theirs.black, ScorePair.theirs.red),
        (Suit.clubs, Suit.hearts),
      );
    });

    testWidgets('at 0 lie side by side, not overlapping', (tester) async {
      for (final (pair, order) in [
        (ScorePair.ours, ['6S', '6D']),
        (ScorePair.theirs, ['6H', '6C']),
      ]) {
        await showCorner(tester, pair: pair);

        expect(wholeSixes(tester), [for (final id in order) Card.parse(id)]);
        final cards = find.descendant(
          of: sixes,
          matching: find.byType(PlayingCard),
        );
        final left = tester.getRect(cards.at(0));
        final right = tester.getRect(cards.at(1));
        expect(
          (left.right <= right.left) || (right.right <= left.left),
          isTrue,
          reason: '$pair',
        );
      }
    });

    testWidgets('at 1 to 5 show that many pips of the six of that sign', (
      tester,
    ) async {
      for (final (pair, score, suit) in [
        (ScorePair.ours, 3, Suit.diamonds),
        (ScorePair.ours, -2, Suit.spades),
        (ScorePair.theirs, 4, Suit.hearts),
        (ScorePair.theirs, -1, Suit.clubs),
        (ScorePair.theirs, 5, Suit.hearts),
      ]) {
        await showCorner(tester, pair: pair, score: score);

        expect(
          scoreArt(tester),
          resolver.scoreSix(suit, score.abs()),
          reason: '$pair $score',
        );
        expect(wholeSixes(tester), isEmpty);
      }
    });

    testWidgets('at 6 or more show the whole six of that sign', (tester) async {
      for (final (pair, score, six) in [
        (ScorePair.ours, 6, '6D'),
        (ScorePair.ours, -6, '6S'),
        (ScorePair.theirs, 6, '6H'),
        (ScorePair.theirs, -7, '6C'),
      ]) {
        await showCorner(tester, pair: pair, score: score);

        expect(wholeSixes(tester), [Card.parse(six)], reason: '$score');
      }
    });

    testWidgets('fit the same box at every score', (tester) async {
      for (var score = -7; score <= 7; score++) {
        await showCorner(tester, score: score);

        expect(
          tester.getSize(sixes),
          Size(120 * TeamCorner.sixesFactor, TeamCorner.artHeight(120)),
          reason: '$score',
        );
      }
    });

    testWidgets("the owner's covered sixes are decoded and drawn", (
      tester,
    ) async {
      for (final (pair, sign) in [
        (ScorePair.ours, 1),
        (ScorePair.ours, -1),
        (ScorePair.theirs, 1),
        (ScorePair.theirs, -1),
      ]) {
        for (var pips = 1; pips <= CardAssetResolver.maxCoveredPips; pips++) {
          await showCorner(tester, pair: pair, score: sign * pips);
          await tester.runAsync(
            () => precacheImage(
              tester.widget<Image>(find.byType(Image)).image,
              tester.element(find.byType(TeamCorner)),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(MissingCardAsset), findsNothing);
          expect(
            tester.widget<RawImage>(find.byType(RawImage)).image,
            isNotNull,
            reason: '${pair.red} ${sign * pips}',
          );
        }
      }
    });

    testWidgets('art that is missing shows a labelled stand-in', (
      tester,
    ) async {
      await showCorner(
        tester,
        score: 2,
        overrides: [
          cardAssetResolverProvider.overrideWithValue(
            const CardAssetResolver(directory: 'assets/not-supplied'),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(MissingCardAsset), findsOneWidget);
      expect(
        find.text('Missing asset\n6_of_diamonds_2_visible.webp'),
        findsOneWidget,
      );
    });
  });

  group('the match card (AGENTS.md §6.13)', () {
    test('is 5, 4, 3, 2 for 1 to 4 matches, in the sign\'s suit', () {
      expect(matchCard(ScorePair.ours, 0), isNull);
      expect(matchCard(ScorePair.ours, 1), Card.parse('5D'));
      expect(matchCard(ScorePair.ours, 2), Card.parse('4D'));
      expect(matchCard(ScorePair.ours, 3), Card.parse('3D'));
      expect(matchCard(ScorePair.ours, 4), Card.parse('2D'));
      expect(matchCard(ScorePair.ours, -1), Card.parse('5S'));
      expect(matchCard(ScorePair.ours, -4), Card.parse('2S'));
      expect(matchCard(ScorePair.theirs, 2), Card.parse('4H'));
      expect(matchCard(ScorePair.theirs, -3), Card.parse('3C'));
    });

    test('stays the 2 one match beyond, when the game ends', () {
      expect(matchCard(ScorePair.ours, 5), Card.parse('2D'));
      expect(matchCard(ScorePair.theirs, -5), Card.parse('2C'));
    });

    testWidgets('shows the record, and nothing when level', (tester) async {
      await showCorner(tester);
      expect(shownMatchCard(tester), isNull);

      await showCorner(tester, record: 2);
      expect(shownMatchCard(tester), Card.parse('4D'));

      await showCorner(tester, pair: ScorePair.theirs, record: -2);
      expect(shownMatchCard(tester), Card.parse('4C'));
    });

    testWidgets('shows none in the corner without the card', (tester) async {
      await pumpInApp(
        tester,
        const TeamCorner(
          pair: ScorePair.ours,
          team: 'Us',
          score: 0,
          record: 2,
          width: 120,
          holdsCard: false,
        ),
      );
      expect(shownMatchCard(tester), isNull);
    });

    testWidgets('sits on the side toward the middle', (tester) async {
      await showCorner(tester, record: 1);
      final card = find.byKey(const ValueKey('match-card'));
      expect(
        tester.getRect(card).left,
        greaterThan(tester.getRect(sixes).right),
      );

      await showCorner(tester, pair: ScorePair.theirs, record: 1);
      expect(tester.getRect(card).right, lessThan(tester.getRect(sixes).left));
    });
  });

  testWidgets('writes the points and tells screen readers the record', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await showCorner(tester, score: 3, record: 1);

    expect(find.text('Us 3'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Us: 3 game points, 1 match ahead'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('Six of')), findsNothing);

    await showCorner(tester, pair: ScorePair.theirs, score: -2, record: -2);
    expect(
      find.bySemanticsLabel('Them: -2 game points, 2 matches behind'),
      findsOneWidget,
    );
    await showCorner(tester);
    expect(
      find.bySemanticsLabel('Us: 0 game points, level in matches'),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
