import 'package:card_games/shared/cards/card_asset_resolver.dart';
import 'package:card_games/shared/cards/playing_card.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

import '../../helpers/pump_app.dart';

void main() {
  /// The asset an [Image] shows and the width it is decoded at.
  (String, int?) decoded(WidgetTester tester) {
    final provider = tester.widget<Image>(find.byType(Image)).image;
    final resize = provider as ResizeImage;
    return ((resize.imageProvider as AssetImage).assetName, resize.width);
  }

  testWidgets('draws the face from the resolved asset', (tester) async {
    await pumpInApp(tester, PlayingCard.face(Card.parse('JH')));

    expect(decoded(tester).$1, 'assets/cards/jack_of_hearts2.png');
  });

  testWidgets('decodes images at display size', (tester) async {
    await pumpInApp(tester, const PlayingCard.back(width: 100));

    final pixelRatio = tester.view.devicePixelRatio;
    expect(decoded(tester).$2, (100 * pixelRatio).round());
  });

  testWidgets('draws the back from the resolved asset', (tester) async {
    await pumpInApp(tester, const PlayingCard.back());

    expect(decoded(tester).$1, 'assets/cards/back.png');
  });

  testWidgets('draws the back on a white card, its art whole', (tester) async {
    await pumpInApp(tester, const PlayingCard.back(width: 100));
    // The nearest box under the art is the card's body.
    final body = find
        .ancestor(of: find.byType(Image), matching: find.byType(ColoredBox))
        .first;
    expect(tester.widget<ColoredBox>(body).color, PlayingCard.backColor);
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);

    await tester.runAsync(
      () => precacheImage(
        tester.widget<Image>(find.byType(Image)).image,
        tester.element(find.byType(PlayingCard)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MissingCardAsset), findsNothing);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
  });

  testWidgets('has the size of a standard card', (tester) async {
    await pumpInApp(tester, PlayingCard.face(Card.parse('JH'), width: 250));

    expect(tester.getSize(find.byType(PlayingCard)), const Size(250, 363));
  });

  testWidgets('supplied art is decoded and drawn', (tester) async {
    await pumpInApp(tester, PlayingCard.face(Card.parse('10S')));
    await tester.runAsync(
      () => precacheImage(
        tester.widget<Image>(find.byType(Image)).image,
        tester.element(find.byType(PlayingCard)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MissingCardAsset), findsNothing);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
  });

  testWidgets('missing art shows a labelled stand-in in debug builds', (
    tester,
  ) async {
    await pumpInApp(
      tester,
      PlayingCard.face(Card.parse('10S')),
      overrides: [
        cardAssetResolverProvider.overrideWithValue(
          const CardAssetResolver(directory: 'assets/not-supplied'),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(MissingCardAsset), findsOneWidget);
    expect(find.text('Missing asset\n10_of_spades.png'), findsOneWidget);
  });

  testWidgets('screen readers hear the card name', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpInApp(tester, PlayingCard.face(Card.parse('QD')));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Queen of Diamonds'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('screen readers hear a face-down card', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpInApp(tester, const PlayingCard.back());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Face-down card'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Missing')), findsNothing);
    semantics.dispose();
  });
}
