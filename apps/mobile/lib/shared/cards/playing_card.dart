import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';

import '../../l10n/app_localizations.dart';
import 'card_asset_resolver.dart';

/// A face-up or face-down card, drawn from the owner's card art.
///
/// If the image is missing, debug builds show a labelled stand-in
/// (AGENTS.md §13) and other builds show an empty outline.
class PlayingCard extends ConsumerWidget {
  /// The face of [card].
  const PlayingCard.face(
    Card this.card, {
    super.key,
    this.width = defaultWidth,
  });

  /// A face-down card.
  const PlayingCard.back({super.key, this.width = defaultWidth}) : card = null;

  /// Width divided by height of the owner's card faces (500 × 726 pixels).
  static const double aspectRatio = 500 / 726;

  /// The width used when none is given.
  static const double defaultWidth = 72;

  /// Corner radius as a fraction of the width, matching the faces' corners.
  static const double cornerRadiusFactor = 0.035;

  /// The card under the back's art, which the owner drew on a transparent
  /// background: white, like the faces.
  static const Color backColor = Color(0xFFFFFFFF);

  /// The card to show face up, or null to show the back.
  final Card? card;

  /// The width of the card. The height follows from [aspectRatio].
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolver = ref.watch(cardAssetResolverProvider);
    final l10n = AppLocalizations.of(context);
    final card = this.card;
    final path = card == null ? resolver.back : resolver.face(card);
    final label = card == null
        ? l10n.cardBackLabel
        : l10n.cardFaceLabel(
            l10n.rankName(card.rank.name),
            l10n.suitName(card.suit.name),
          );
    // Decode at display size: the back is 2500 × 3500 pixels and would take
    // about 35 MB of memory at full size.
    final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final image = Image.asset(
      path,
      // The back's art is a little wider than a face; it keeps its shape.
      fit: card == null ? BoxFit.contain : BoxFit.fill,
      cacheWidth: (width * pixelRatio).round(),
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) =>
          MissingCardAsset(path: path),
    );
    return Semantics(
      label: label,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: width / aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(width * cornerRadiusFactor),
          child: card == null
              ? ColoredBox(color: backColor, child: image)
              : image,
        ),
      ),
    );
  }
}

/// Stands in for card art the owner has not supplied yet.
///
/// Debug builds label it with the missing file name. Release builds draw an
/// empty outline and never a substitute image.
class MissingCardAsset extends StatelessWidget {
  /// Creates a stand-in for the asset at [path].
  const MissingCardAsset({super.key, required this.path});

  /// The asset path that could not be loaded.
  final String path;

  static const Color _debugRed = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x33000000)),
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x1FC62828),
        border: Border.all(color: _debugRed, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            '${AppLocalizations.of(context).missingCardAsset}\n'
            '${path.split('/').last}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _debugRed,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
