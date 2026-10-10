import 'package:game_core/game_core.dart';
import 'package:material_ui/material_ui.dart' hide Card;

import '../../l10n/app_localizations.dart';
import '../../shared/cards/playing_card.dart';

/// Shows every card face and the card back, so the owner's card art can be
/// checked at a glance. Debug builds only.
class CardGalleryScreen extends StatelessWidget {
  /// Creates the gallery.
  const CardGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).debugCardGalleryTitle),
      ),
      body: GridView.extent(
        maxCrossAxisExtent: 88,
        padding: const EdgeInsets.all(12),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: PlayingCard.aspectRatio,
        children: [
          for (final card in Card.values) PlayingCard.face(card),
          const PlayingCard.back(),
        ],
      ),
    );
  }
}
